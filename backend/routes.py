import datetime
from flask import Blueprint, request, jsonify
from utils import extract_call_info, process_command
from firebase_admin import messaging, firestore, auth as fb_auth
import firebase_admin

api_bp = Blueprint('api', __name__)

TRIAL_DAYS = 3

def _token_to_str(token):
    """Safely convert a custom token to a string.
    Older firebase-admin versions return bytes, newer ones return str."""
    return token.decode('utf-8') if isinstance(token, bytes) else str(token)

def get_or_create_user_trial(doc_ref, doc_data):
    now_iso = datetime.datetime.now(datetime.timezone.utc).isoformat()
    updates = {}
    
    created_at = doc_data.get('created_at')
    if not created_at:
        created_at = now_iso
        updates['created_at'] = now_iso
        
    if 'is_subscribed' not in doc_data:
        updates['is_subscribed'] = False
        
    if updates and doc_ref:
        try:
            doc_ref.update(updates)
        except Exception as e:
            print(f"Error updating user trial fields: {e}")
            
    is_subscribed = doc_data.get('is_subscribed', False) if 'is_subscribed' in doc_data else False
    return created_at, is_subscribed

@api_bp.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    if not data or 'role' not in data:
        return jsonify({"error": "Missing credentials"}), 400
        
    role = data['role']
    
    if role == 'admin':
        username = data.get('username', '').strip() if data.get('username') else None
        password = data.get('password')
        if not username or not password:
            return jsonify({"error": "Username and password required"}), 400
            
        if not firebase_admin._apps:
            return jsonify({"error": "Firebase not initialized"}), 500
            
        db = firestore.client()
        admins = db.collection('admins').where('username', '==', username).where('password', '==', password).get()
        
        if admins:
            admin_doc = admins[0]
            admin_data = admin_doc.to_dict()
            created_at, is_subscribed = get_or_create_user_trial(admin_doc.reference, admin_data)
            return jsonify({
                "success": True,
                "role": "admin",
                "username": username,
                "created_at": created_at,
                "is_subscribed": is_subscribed,
                "custom_token": _token_to_str(fb_auth.create_custom_token(username)),
                "trial_days": TRIAL_DAYS
            }), 200
        else:
            return jsonify({"error": "Invalid admin credentials"}), 401
            
    elif role == 'technician':
        name = data.get('name', '').strip() if data.get('name') else None
        pin = data.get('pin')
        
        if not name or not pin:
            return jsonify({"error": "Name and PIN required"}), 400
            
        if not firebase_admin._apps:
            return jsonify({"error": "Firebase not initialized"}), 500
            
        db = firestore.client()
        techs = db.collection('technicians').where('name', '==', name).where('pin', '==', pin).get()
        
        if techs:
            tech_doc = techs[0]
            tech_data = tech_doc.to_dict()
            created_at, is_subscribed = get_or_create_user_trial(tech_doc.reference, tech_data)
            return jsonify({
                "success": True,
                "role": "technician",
                "technician_name": name,
                "created_at": created_at,
                "is_subscribed": is_subscribed,
                "custom_token": _token_to_str(fb_auth.create_custom_token(name)),
                "trial_days": TRIAL_DAYS
            }), 200
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
    now_iso = datetime.datetime.now(datetime.timezone.utc).isoformat()
    
    if role == 'admin':
        username = data.get('username', '').strip() if data.get('username') else None
        password = data.get('password')
        if not username or not password:
            return jsonify({"error": "Username and password required"}), 400
            
        existing = db.collection('admins').where('username', '==', username).get()
        if existing:
            return jsonify({"error": "Admin username already exists"}), 409
            
        db.collection('admins').add({
            'username': username,
            'password': password,
            'created_at': now_iso,
            'is_subscribed': False
        })
        return jsonify({
            "success": True,
            "message": "Admin account created",
            "created_at": now_iso,
            "trial_days": TRIAL_DAYS
        }), 201
        
    elif role == 'technician':
        name = data.get('name', '').strip() if data.get('name') else None
        pin = data.get('pin')
        if not name or not pin:
            return jsonify({"error": "Name and PIN required"}), 400
            
        phone = data.get('phone', '')
        email = data.get('email', '')
        specialty = data.get('specialty', '')
        
        existing = db.collection('technicians').where('name', '==', name).get()
        if existing:
            return jsonify({"error": "Technician name already exists"}), 409
            
        db.collection('technicians').add({
            'name': name,
            'pin': pin,
            'phone': phone,
            'email': email,
            'specialty': specialty,
            'created_at': now_iso,
            'is_subscribed': False
        })
        return jsonify({
            "success": True,
            "message": "Technician account created",
            "created_at": now_iso,
            "trial_days": TRIAL_DAYS
        }), 201
        
    return jsonify({"error": "Invalid role"}), 400

@api_bp.route('/subscription/status', methods=['GET'])
def subscription_status():
    username = request.args.get('username')
    role = request.args.get('role', 'admin')
    
    if not firebase_admin._apps:
        return jsonify({"error": "Firebase not initialized"}), 500
        
    db = firestore.client()
    collection = 'admins' if role == 'admin' else 'technicians'
    field = 'username' if role == 'admin' else 'name'
    
    if not username:
        return jsonify({"trial_days": TRIAL_DAYS, "is_subscribed": False}), 200
        
    docs = db.collection(collection).where(field, '==', username).get()
    if docs:
        user_doc = docs[0]
        d = user_doc.to_dict()
        created_at_str, is_sub = get_or_create_user_trial(user_doc.reference, d)
        return jsonify({
            "trial_days": TRIAL_DAYS,
            "created_at": created_at_str,
            "is_subscribed": is_sub
        }), 200
        
    return jsonify({"trial_days": TRIAL_DAYS, "is_subscribed": False}), 200

@api_bp.route('/subscription/upgrade', methods=['POST'])
def subscription_upgrade():
    data = request.get_json() or {}
    username = data.get('username')
    role = data.get('role', 'admin')
    
    if not firebase_admin._apps:
        return jsonify({"error": "Firebase not initialized"}), 500
        
    db = firestore.client()
    collection = 'admins' if role == 'admin' else 'technicians'
    field = 'username' if role == 'admin' else 'name'
    
    if username:
        docs = db.collection(collection).where(field, '==', username).get()
        if docs:
            docs[0].reference.update({'is_subscribed': True})
            
    return jsonify({"success": True, "message": "Successfully upgraded to Pro subscription!", "is_subscribed": True}), 200


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
        
    tech_name = data.get("technician_assigned", "").strip() if data.get("technician_assigned") else None
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
    if not data or 'command' not in data or 'uid' not in data:
        return jsonify({"error": "Missing 'command' or 'uid' in request body"}), 400

    command_text = data['command']
    uid = data['uid']
    intent = process_command(command_text)
    
    if not intent:
        return jsonify({"error": "Could not understand command."}), 400

    action = intent.get("action")
    target_name = intent.get("target_name", "").strip() if intent.get("target_name") else None
    customer_name = intent.get("customer_name", "").strip() if intent.get("customer_name") else None
    params = intent.get("parameters", {})
    
    if action == "unknown":
        reply = intent.get("reply", "I can only help manage service calls and technicians.")
        return jsonify({"message": reply}), 200
        
    if not firebase_admin._apps:
        return jsonify({"error": "Firebase not initialized"}), 500
        
    db = firestore.client()
    
    if action == "get_technicians":
        techs = db.collection('technicians').where('ownerId', '==', uid).get()
        names = [t.to_dict().get('name') for t in techs]
        if names:
            return jsonify({"message": f"The current technicians are: {', '.join(names)}."}), 200
        return jsonify({"message": "There are no technicians currently registered."}), 200

    elif action == "add_technician":
        tech_name_raw = target_name or customer_name or params.get("technician_assigned")
        tech_name = tech_name_raw.strip() if tech_name_raw else None
        if not tech_name:
            return jsonify({"error": "I need a name to add a technician."}), 400
            
        pin = params.get("technician_pin", "0000")
        spec = params.get("technician_specialty", "")
        phone = params.get("phone", "")
        
        db.collection('technicians').add({
            'ownerId': uid, 'name': tech_name, 'pin': pin, 'specialty': spec, 'phone': phone, 'email': '',
            'created_at': firestore.SERVER_TIMESTAMP
        })
        return jsonify({"message": f"Successfully added {tech_name} as a technician."}), 200

    elif action == "delete_technician":
        if not target_name:
            return jsonify({"error": "I need to know who to delete."}), 400
        techs = db.collection('technicians').where('ownerId', '==', uid).where('name', '==', target_name).get()
        if not techs:
            return jsonify({"error": f"Technician {target_name} not found."}), 404
        for t in techs:
            t.reference.delete()
        return jsonify({"message": f"Successfully removed technician {target_name}."}), 200

    elif action == "update_technician":
        if not target_name:
            return jsonify({"error": "I need to know who to update."}), 400
        techs = db.collection('technicians').where('ownerId', '==', uid).where('name', '==', target_name).get()
        if not techs:
            return jsonify({"error": f"Technician {target_name} not found."}), 404
        updates = {}
        if params.get("technician_specialty"): updates["specialty"] = params.get("technician_specialty")
        if params.get("phone"): updates["phone"] = params.get("phone")
        if updates:
            techs[0].reference.update(updates)
            return jsonify({"message": f"Successfully updated technician {target_name}."}), 200
        return jsonify({"message": "No updates were specified."}), 200

    elif action == "delete_call":
        if not target_name:
            return jsonify({"error": "I need the customer name to delete their call."}), 400
        all_calls = db.collection('calls').where('ownerId', '==', uid).get()
        call_doc = next((c for c in all_calls if c.to_dict().get('customer', {}).get('name') and target_name.lower() in c.to_dict().get('customer', {}).get('name', '').lower()), None)
        if not call_doc:
            return jsonify({"error": f"No calls found for {target_name}."}), 404
        call_doc.reference.delete()
        return jsonify({"message": f"Successfully deleted the call for {target_name}."}), 200

    elif action == "get_calls":
        calls = db.collection('calls').where('ownerId', '==', uid).where('status', '==', 'Pending').get()
        if not calls:
            return jsonify({"message": "There are currently no pending calls."}), 200
        return jsonify({"message": f"There are {len(calls)} pending calls currently in the system."}), 200

    elif action == "create_call":
        c_name_raw = customer_name or target_name or "Unknown Customer"
        c_name = c_name_raw.strip() if c_name_raw else "Unknown Customer"
        phone = params.get("phone")
        
        # Find or create customer
        customers_ref = db.collection('customers')
        query = customers_ref.where('ownerId', '==', uid).where('phone', '==', phone).get() if phone else None
        
        if query:
            customer_doc = query[0]
            customer_id = customer_doc.id
            customer_data = customer_doc.to_dict()
        else:
            # Create new customer
            _, new_customer_ref = customers_ref.add({
                'ownerId': uid,
                'name': c_name,
                'phone': phone or '',
                'address': '',
                'created_at': firestore.SERVER_TIMESTAMP
            })
            customer_id = new_customer_ref.id
            customer_data = {'name': c_name, 'phone': phone or ''}
            
        new_call_ref = db.collection('calls').document()
        call_data = {
            'ownerId': uid,
            'customer_id': customer_id,
            'customer': {
                'name': customer_data.get('name', 'Unknown'),
                'phone': customer_data.get('phone', '')
            },
            'call_type': "Service",
            'problem_description': params.get("problem_description", "No description provided"),
            'priority': params.get("priority", "Medium"),
            'status': params.get("status", "Pending"),
            'technician_assigned': params.get("technician_assigned", "").strip() if params.get("technician_assigned") else None,
            'raw_input': command_text,
            'created_at': firestore.SERVER_TIMESTAMP,
            'updated_at': firestore.SERVER_TIMESTAMP
        }
        new_call_ref.set(call_data)
        
        db.collection('call_updates').add({
            'ownerId': uid,
            'call_id': new_call_ref.id,
            'note': "AI Assistant: Call created.",
            'status_change': call_data['status'],
            'created_at': firestore.SERVER_TIMESTAMP
        })
        
        return jsonify({
            "message": f"Successfully created a new call for {customer_data['name']}."
        }), 200

    elif action == "update_call":
        if not target_name:
            return jsonify({"error": "Could not identify which customer to update."}), 400
            
        all_calls = db.collection('calls').where('ownerId', '==', uid).order_by('created_at', direction=firestore.Query.DESCENDING).get()
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
        new_status = params.get("status")
        new_priority = params.get("priority")
        new_tech = params.get("technician_assigned", "").strip() if params.get("technician_assigned") else None
        
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
            
        call_doc.reference.update(update_payload)
        update_note = "AI Assistant: " + ", ".join(note_parts)
        
        db.collection('call_updates').add({
            'ownerId': uid,
            'call_id': call_doc.id,
            'note': update_note,
            'status_change': new_status if new_status else None,
            'created_at': firestore.SERVER_TIMESTAMP
        })
        
        if new_tech and call_data.get('priority') == 'High':
            notify_technician_internal(new_tech, f"New High Priority Call: {matched_customer_name}", params.get("problem_description", "Urgent"))
        elif new_tech and new_priority == 'High':
            notify_technician_internal(new_tech, f"Call Upgraded to High Priority: {matched_customer_name}", params.get("problem_description", "Urgent"))
        
        return jsonify({"message": f"Successfully updated call for {matched_customer_name}."}), 200

    return jsonify({"error": "Action not supported."}), 400

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

@api_bp.route('/app/version', methods=['GET'])
def app_version():
    """Returns the latest app version and update URL for in-app updates."""
    return jsonify({
        "latest_version": "1.0.1",
        "min_required_version": "1.0.0",
        "update_url": "https://github.com/whoisadheep/GridCRM/releases/latest/download/app-release.apk",
        "release_notes": "Security updates and transition to new Auto Updater.",
        "force_update": True
    }), 200

