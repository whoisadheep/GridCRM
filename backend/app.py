import os
import firebase_admin
from firebase_admin import credentials
from flask import Flask
from flask_cors import CORS
from dotenv import load_dotenv
from models import db
from routes import api_bp

def create_app():
    load_dotenv()
    
    app = Flask(__name__)
    CORS(app)

    # Initialize Firebase Admin
    cred_path = os.path.join(os.path.dirname(__file__), 'firebase-admin.json')
    if os.path.exists(cred_path) and not firebase_admin._apps:
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)

    # Use DATABASE_URL if provided, else fallback to local sqlite for development
    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        basedir = os.path.abspath(os.path.dirname(__file__))
        database_url = 'sqlite:///' + os.path.join(basedir, 'app.db')

    app.config['SQLALCHEMY_DATABASE_URI'] = database_url
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

    db.init_app(app)

    # Register blueprints
    app.register_blueprint(api_bp, url_prefix='/api')

    with app.app_context():
        db.create_all()

    return app

if __name__ == '__main__':
    app = create_app()
    app.run(host='0.0.0.0', debug=True, port=5000)
