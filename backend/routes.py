import datetime
from flask import Blueprint, request, jsonify
from utils import extract_call_info, process_command
from firebase_admin import messaging, firestore
import firebase_admin

api_bp = Blueprint('api', __name__)

@api_bp.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    if not data or 'role' not in data:
        return jsonify({"error": "Missing credentials"}), 400
        
    role = data['role']
    
    if role == 'admin':
        username = data.get('username')
        password = data.get('password')
        if not username or not password:
            return jsonify({"error": "Username and password required"}), 400
            
        if not firebase_admin._apps:
            return jsonify({"error": "Firebase not initialized"}), 500
            
        db = firestore.client()
        admins = db.collection('admins').where('username', '==', username).where('password', '==', password).get()
        
        if admins:
            return jsonify({"success": True, "role": "admin"}), 200
        else:
            return jsonify({"error": "Invalid admin credentials"}), 401
            
    elif role == 'technician':
        name = data.get('name')
        pin = data.get('pin')
        
        if not name or not pin:
            return jsonify({"error": "Name and PIN required"}), 400
            
        if not firebase_admin._apps:
            return jsonify({"error": "Firebase not initialized"}), 500
            
        db = firestore.client()
        techs = db.collection('technicians').where('name', '==', name).where('pin', '==', pin).get()
        
        if techs:
            return jsonify({"success": True, "role": "technician", "technician_name": name}), 200
        else:
            return jsonify({"error": "Invalid technician credentials"}), 401
            
    return jsonify({"error": "Invalid role"}), 400

@api_bp.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    if not data or 'role' not in data:
        return jsonify({"error": "Missing registration details"}), 400
        
    role = data['role']
    db = firestore.client()
    
    if role == 'admin':
        username = data.get('username')
        password = data.get('password')
        if not username or not password:
            return jsonify({"error": "Username and password required"}), 400
            
        existing = db.collection('admins').where('username', '==', username).get()
        if existing:
            return jsonify({"error": "Admin username already exists"}), 409
            
        db.collection('admins').add({
            'username': username,
            'password': password
        })
        return jsonify({"success": True, "message": "Admin account created"}), 201
        
    elif role == 'technician':
        name = data.get('name')
        pin = data.get('pin')
        if not name or not pin:
            return jsonify({"error": "Name and PIN required"}), 400
            
        existing = db.collection('technicians').where('name', '==', name).get()
        if existing:
            return jsonify({"error": "Technician name already exists"}), 409
            
        db.collection('technicians').add({
            'name': name,
            'pin': pin
        })
        return jsonify({"success": True, "message": "Technician account created"}), 201
        
    return jsonify({"error": "Invalid role"}), 400

@api_bp.route('/calls/extract', methods=['POST'])
def extract_call():
    data = request.get_json()
    if not data or 'raw_text' not in data:
        return jsonify({"error": "Missing raw_text in request body"}), 400
    
    raw_text = data['raw_text']
    extracted = extract_call_info(raw_text)
    return jsonify(extracted), 200

@api_bp.route('/notify', methods=['POST'])
def notify_technician():
    data = request.get_json()
    if not data:
        return jsonify({"error": "Missing request body"}), 400
        
    tech_name = data.get("technician_assigned")
    title = data.get("title", "New Call Assigned")
    body = data.get("body", "You have a new high priority call.")
    
    if not tech_name:
        return jsonify({"error": "technician_assigned is required"}), 400
        
    if not firebase_admin._apps:
        return jsonify({"error": "Firebase not initialized"}), 500
        
    db = firestore.client()
    # Find the technician by name to get their FCM token
    techs = db.collection('technicians').where('name', '==', tech_name).get()
    
    if not techs:
        return jsonify({"error": "Technician not found"}), 404
        
    tech_data = techs[0].to_dict()
    fcm_token = tech_data.get('fcm_token')
    
    if not fcm_token:
        return jsonify({"error": "Technician does not have push notifications enabled"}), 400
        
    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body
            ),
            token=fcm_token,
        )
        messaging.send(message)
        return jsonify({"success": True, "message": "Notification sent"}), 200
    except Exception as e:
        print(f"Error sending push notification: {e}")
        return jsonify({"error": str(e)}), 500

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
        
    if not firebase_admin._apps:
        return jsonify({"error": "Firebase not initialized"}), 500
        
    db = firestore.client()
        
    if action == "create_call":
        customer_name = intent.get("customer_name") or "Unknown Customer"
        phone = intent.get("phone")
        if not phone:
            return jsonify({"error": "I need a phone number to create a new call."}), 400
            
        # Find or create customer
        customers_ref = db.collection('customers')
        query = customers_ref.where('phone', '==', phone).get()
        
        if query:
            customer_doc = query[0]
            customer_id = customer_doc.id
            customer_data = customer_doc.to_dict()
        else:
            # Create new customer
            _, new_customer_ref = customers_ref.add({
                'name': customer_name,
                'phone': phone,
                'address': '',
                'created_at': firestore.SERVER_TIMESTAMP
            })
            customer_id = new_customer_ref.id
            customer_data = {'name': customer_name, 'phone': phone}
            
        updates = intent.get("updates", {})
        
        # Create call
        new_call_ref = db.collection('calls').document()
        call_data = {
            'customer_id': customer_id,
            'customer': {
                'name': customer_data.get('name', 'Unknown'),
                'phone': customer_data.get('phone', '')
            },
            'call_type': "Service",
            'problem_description': updates.get("problem_description", "No description provided"),
            'priority': updates.get("priority", "Medium"),
            'status': updates.get("status", "Pending"),
            'technician_assigned': updates.get("technician_assigned", None),
            'raw_input': command_text,
            'created_at': firestore.SERVER_TIMESTAMP,
            'updated_at': firestore.SERVER_TIMESTAMP
        }
        new_call_ref.set(call_data)
        
        db.collection('call_updates').add({
            'call_id': new_call_ref.id,
            'note': "AI Assistant: Call created.",
            'status_change': call_data['status'],
            'created_at': firestore.SERVER_TIMESTAMP
        })
        
        return jsonify({
            "message": f"Successfully created a new call for {customer_data['name']}."
        }), 200

    if action != "update_call":
        return jsonify({"error": "Action not supported."}), 400
        
    target_name = intent.get("target_name")
    if not target_name:
        return jsonify({"error": "Could not identify which customer to update."}), 400
        
    # Find the most recent call matching the target_name in its customer object
    all_calls = db.collection('calls').order_by('created_at', direction=firestore.Query.DESCENDING).get()
    
    call_doc = None
    matched_customer_name = None
    
    for c in all_calls:
        c_data = c.to_dict()
        cust = c_data.get('customer', {})
        cust_name = cust.get('name', '')
        if cust_name and target_name.lower() in cust_name.lower():
            call_doc = c
            matched_customer_name = cust_name
            break
            
    if not call_doc:
        return jsonify({"error": f"No active calls found for customer '{target_name}'."}), 404
        
    call_data = call_doc.to_dict()
        
    updates = intent.get("updates", {})
    new_status = updates.get("status")
    new_priority = updates.get("priority")
    new_tech = updates.get("technician_assigned")
    
    note_parts = []
    update_payload = {'updated_at': firestore.SERVER_TIMESTAMP}
    
    if new_status and new_status != call_data.get('status'):
        note_parts.append(f"Status changed to {new_status}")
        update_payload['status'] = new_status
    if new_priority and new_priority != call_data.get('priority'):
        note_parts.append(f"Priority changed to {new_priority}")
        update_payload['priority'] = new_priority
    if new_tech and new_tech != call_data.get('technician_assigned'):
        note_parts.append(f"Assigned to {new_tech}")
        update_payload['technician_assigned'] = new_tech
        
    if not note_parts:
        return jsonify({"message": "No changes needed."}), 200
        
    # Update call
    call_doc.reference.update(update_payload)
        
    update_note = "AI Assistant: " + ", ".join(note_parts)
    
    db.collection('call_updates').add({
        'call_id': call_doc.id,
        'note': update_note,
        'status_change': new_status if new_status else None,
        'created_at': firestore.SERVER_TIMESTAMP
    })
    
    # Notify if assigned and high priority
    if new_tech and call_data.get('priority') == 'High':
        notify_technician_internal(new_tech, f"New High Priority Call: {matched_customer_name}", updates.get("problem_description", "Urgent"))
    elif new_tech and new_priority == 'High':
        notify_technician_internal(new_tech, f"Call Upgraded to High Priority: {matched_customer_name}", updates.get("problem_description", "Urgent"))
    
    return jsonify({
        "message": f"Successfully updated call for {matched_customer_name}."
    }), 200

def notify_technician_internal(tech_name, title, body):
    db = firestore.client()
    techs = db.collection('technicians').where('name', '==', tech_name).get()
    if not techs:
        return
    fcm_token = techs[0].to_dict().get('fcm_token')
    if fcm_token:
        try:
            msg = messaging.Message(
                notification=messaging.Notification(title=title, body=body),
                token=fcm_token,
            )
            messaging.send(msg)
        except Exception as e:
            print(f"Error sending push: {e}")
