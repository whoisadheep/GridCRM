from flask import Blueprint, request, jsonify
from models import db, Customer, Call, CallUpdate, Technician
from utils import extract_call_info, process_command
from firebase_admin import messaging
import firebase_admin

api_bp = Blueprint('api', __name__)

@api_bp.route('/calls/extract', methods=['POST'])
def extract_call():
    data = request.get_json()
    if not data or 'raw_text' not in data:
        return jsonify({"error": "Missing raw_text in request body"}), 400
    
    raw_text = data['raw_text']
    extracted = extract_call_info(raw_text)
    return jsonify(extracted), 200

@api_bp.route('/calls', methods=['POST'])
def create_call():
    data = request.get_json()
    if not data:
        return jsonify({"error": "Missing request body"}), 400

    phone = data.get("phone_number")
    if not phone:
        return jsonify({"error": "phone_number is required"}), 400

    # Look up customer
    customer = Customer.query.filter_by(phone=phone).first()
    
    if not customer:
        customer = Customer(
            name=data.get("customer_name"),
            phone=phone,
            address=data.get("address") # Address isn't extracted by default, but might be passed from client
        )
        db.session.add(customer)
        db.session.flush() # get customer.id
    else:
        # Fill in blank info if provided
        if not customer.name and data.get("customer_name"):
            customer.name = data.get("customer_name")
        if not customer.address and data.get("address"):
            customer.address = data.get("address")

    call = Call(
        customer_id=customer.id,
        call_type=data.get("call_type", "Other"),
        problem_description=data.get("problem_description", ""),
        priority=data.get("priority", "Medium"),
        raw_input=data.get("raw_input", ""),
        status="Pending",
        technician_assigned=data.get("technician_assigned")
    )
    db.session.add(call)
    db.session.flush()

    update = CallUpdate(
        call_id=call.id,
        note="Call created.",
        status_change="Pending"
    )
    db.session.add(update)
    db.session.commit()

    if call.technician_assigned and call.priority == "High":
        _notify_technician(call.technician_assigned, call)

    return jsonify(call.to_dict(include_customer=True)), 201

@api_bp.route('/calls', methods=['GET'])
def list_calls():
    status = request.args.get('status')
    priority = request.args.get('priority')
    q = request.args.get('q')
    tech = request.args.get('technician_assigned')

    query = Call.query.join(Customer)

    if status:
        query = query.filter(Call.status == status)
    if priority:
        query = query.filter(Call.priority == priority)
    if tech:
        query = query.filter(Call.technician_assigned == tech)
    if q:
        query = query.filter(
            (Customer.phone.ilike(f"%{q}%")) | 
            (Customer.name.ilike(f"%{q}%"))
        )

    # Order by most recently updated
    calls = query.order_by(Call.updated_at.desc()).all()
    
    return jsonify([call.to_dict(include_customer=True) for call in calls]), 200

@api_bp.route('/calls/<int:call_id>', methods=['GET'])
def get_call(call_id):
    call = Call.query.get(call_id)
    if not call:
        return jsonify({"error": "Call not found"}), 404

    call_data = call.to_dict(include_customer=True, include_updates=True)
    
    # get customer's other calls
    past_calls = Call.query.filter(
        Call.customer_id == call.customer_id, 
        Call.id != call.id
    ).order_by(Call.created_at.desc()).all()

    call_data["customer"]["past_calls"] = [
        {
            "id": c.id,
            "status": c.status,
            "problem_description": c.problem_description,
            "created_at": c.created_at.isoformat() if c.created_at else None
        } for c in past_calls
    ]

    return jsonify(call_data), 200

@api_bp.route('/calls/<int:call_id>/update', methods=['POST'])
def update_call(call_id):
    call = Call.query.get(call_id)
    if not call:
        return jsonify({"error": "Call not found"}), 404

    data = request.get_json()
    if not data or 'note' not in data:
        return jsonify({"error": "Missing 'note' in request body"}), 400

    note = data['note']
    new_status = data.get('status')
    new_priority = data.get('priority')
    old_tech = call.technician_assigned
    new_tech = data.get('technician_assigned')

    # Add CallUpdate
    update = CallUpdate(
        call_id=call.id,
        note=note,
        status_change=new_status if new_status and new_status != call.status else None
    )
    db.session.add(update)

    if new_status and new_status != call.status:
        call.status = new_status
    if new_priority and new_priority != call.priority:
        call.priority = new_priority
    if new_tech is not None:
        call.technician_assigned = new_tech

    # updated_at will auto-update due to onupdate
    db.session.commit()

    # Send push notification if technician assignment changed and priority is High
    if new_tech and new_tech != old_tech and call.priority == "High":
        _notify_technician(new_tech, call)

    return jsonify(call.to_dict(include_customer=True, include_updates=True)), 200

@api_bp.route('/calls/<int:call_id>', methods=['DELETE'])
def delete_call(call_id):
    call = Call.query.get(call_id)
    if not call:
        return jsonify({"error": "Call not found"}), 404

    # The CallUpdate cascade might not be configured, so delete updates first to be safe
    CallUpdate.query.filter_by(call_id=call.id).delete()
    
    db.session.delete(call)
    db.session.commit()
    
    return jsonify({"message": "Call deleted successfully"}), 200

@api_bp.route('/technicians', methods=['GET'])
def list_technicians():
    techs = Technician.query.order_by(Technician.name).all()
    return jsonify([t.to_dict() for t in techs]), 200

@api_bp.route('/technicians', methods=['POST'])
def add_technician():
    data = request.get_json()
    name = data.get('name')
    pin = data.get('pin')
    if not name:
        return jsonify({"error": "Name is required"}), 400
    
    # Check if already exists
    if Technician.query.filter_by(name=name).first():
        return jsonify({"error": "Technician already exists"}), 400
        
    tech = Technician(name=name, pin=pin)
    db.session.add(tech)
    db.session.commit()
    return jsonify(tech.to_dict()), 201

@api_bp.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    role = data.get('role')
    
    if role == 'admin':
        username = data.get('username')
        password = data.get('password')
        # Hardcoded admin credentials for MVP
        if username == 'admin' and password == 'admin123':
            return jsonify({"success": True, "role": "admin"}), 200
        return jsonify({"error": "Invalid admin credentials"}), 401
        
    elif role == 'technician':
        name = data.get('name')
        pin = data.get('pin')
        if not name or not pin:
            return jsonify({"error": "Name and PIN required"}), 400
            
        tech = Technician.query.filter_by(name=name).first()
        if not tech or tech.pin != pin:
            return jsonify({"error": "Invalid technician name or PIN"}), 401
            
        return jsonify({"success": True, "role": "technician", "technician_name": tech.name}), 200
        
    return jsonify({"error": "Invalid role specified"}), 400

@api_bp.route('/technicians/token', methods=['PUT'])
def update_technician_token():
    data = request.get_json()
    name = data.get('name')
    fcm_token = data.get('fcm_token')
    
    if not name or not fcm_token:
        return jsonify({"error": "Missing name or token"}), 400
        
    technician = Technician.query.filter_by(name=name).first()
    if technician:
        technician.fcm_token = fcm_token
        db.session.commit()
        return jsonify({"message": "Token updated"}), 200
    
    return jsonify({"error": "Technician not found"}), 404

@api_bp.route('/technicians/<int:tech_id>', methods=['DELETE'])
def delete_technician(tech_id):
    tech = Technician.query.get(tech_id)
    if not tech:
        return jsonify({"error": "Technician not found"}), 404
        
    db.session.delete(tech)
    db.session.commit()
    return jsonify({"message": "Deleted successfully"}), 200

def _notify_technician(tech_name, call):
    if not firebase_admin._apps:
        return
        
    technician = Technician.query.filter_by(name=tech_name).first()
    if not technician or not technician.fcm_token:
        return
        
    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title=f"New Call Assigned: {call.customer.name if call.customer else 'Unknown'}",
                body=f"{call.call_type} - {call.problem_description}"
            ),
            token=technician.fcm_token,
        )
        messaging.send(message)
    except Exception as e:
        print(f"Error sending push notification: {e}")

@api_bp.route('/assistant', methods=['POST'])
def assistant_command():
    data = request.get_json()
    if not data or 'command' not in data:
        return jsonify({"error": "Missing 'command' in request body"}), 400

    command_text = data['command']
    intent = process_command(command_text)
    
    if not intent:
        return jsonify({"error": "Could not understand command."}), 400

    action = intent.get("action")
    if action == "unknown":
        reply = intent.get("reply", "I can only help manage service calls.")
        return jsonify({"message": reply}), 200
        
    if action == "create_call":
        customer_name = intent.get("customer_name") or "Unknown Customer"
        phone = intent.get("phone")
        if not phone:
            return jsonify({"error": "I need a phone number to create a new call."}), 400
            
        customer = Customer.query.filter_by(phone=phone).first()
        if not customer:
            customer = Customer(name=customer_name, phone=phone)
            db.session.add(customer)
            db.session.flush()
            
        updates = intent.get("updates", {})
        call = Call(
            customer_id=customer.id,
            call_type="Service",
            problem_description=updates.get("problem_description", "No description provided"),
            priority=updates.get("priority", "Medium"),
            status=updates.get("status", "Pending"),
            technician_assigned=updates.get("technician_assigned")
        )
        db.session.add(call)
        
        db.session.commit()
        return jsonify({
            "message": f"Successfully created a new call for {customer.name}.",
            "call": call.to_dict(include_customer=True)
        }), 200

    if action != "update_call":
        return jsonify({"error": "Action not supported."}), 400
        
    target_name = intent.get("target_name")
    if not target_name:
        return jsonify({"error": "Could not identify which customer to update."}), 400
        
    # Find customer (simple ilike search)
    customer = Customer.query.filter(Customer.name.ilike(f"%{target_name}%")).first()
    if not customer:
        return jsonify({"error": f"Customer '{target_name}' not found."}), 404
        
    # Get their most recent call
    call = Call.query.filter_by(customer_id=customer.id).order_by(Call.created_at.desc()).first()
    if not call:
        return jsonify({"error": f"No calls found for customer '{target_name}'."}), 404
        
    updates = intent.get("updates", {})
    new_status = updates.get("status")
    new_priority = updates.get("priority")
    new_tech = updates.get("technician_assigned")
    
    note_parts = []
    if new_status and new_status != call.status:
        note_parts.append(f"Status changed to {new_status}")
        call.status = new_status
    if new_priority and new_priority != call.priority:
        note_parts.append(f"Priority changed to {new_priority}")
        call.priority = new_priority
    if new_tech and new_tech != call.technician_assigned:
        note_parts.append(f"Assigned to {new_tech}")
        call.technician_assigned = new_tech
        
    if not note_parts:
        return jsonify({"message": "No changes needed."}), 200
        
    update_note = "AI Assistant: " + ", ".join(note_parts)
    
    call_update = CallUpdate(
        call_id=call.id,
        note=update_note,
        status_change=new_status if new_status else None
    )
    db.session.add(call_update)
    db.session.commit()
    
    return jsonify({
        "message": f"Successfully updated call for {customer.name}.",
        "call": call.to_dict(include_customer=True)
    }), 200
