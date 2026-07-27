import os
import firebase_admin
from firebase_admin import credentials
from flask import Flask
from flask_cors import CORS
from dotenv import load_dotenv
from routes import api_bp

def create_app():
    load_dotenv()
    
    app = Flask(__name__)
    CORS(app)

    # Initialize Firebase Admin
    if not firebase_admin._apps:
        firebase_json_str = os.environ.get('FIREBASE_ADMIN_JSON')
        if firebase_json_str:
            import json
            cred_dict = json.loads(firebase_json_str)
            cred = credentials.Certificate(cred_dict)
            firebase_admin.initialize_app(cred)
        else:
            cred_path = os.path.join(os.path.dirname(__file__), 'firebase-admin.json')
            if os.path.exists(cred_path):
                cred = credentials.Certificate(cred_path)
                firebase_admin.initialize_app(cred)

    # Register blueprints
    app.register_blueprint(api_bp, url_prefix='/api')

    return app

app = create_app()

if __name__ == '__main__':
    app.run(host='0.0.0.0', debug=True, port=5000)
