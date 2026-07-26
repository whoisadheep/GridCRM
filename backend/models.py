from flask_sqlalchemy import SQLAlchemy
from datetime import datetime, timezone

db = SQLAlchemy()

class Customer(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(255), nullable=True)
    phone = db.Column(db.String(50), unique=True, index=True, nullable=False)
    address = db.Column(db.Text, nullable=True)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))

    calls = db.relationship('Call', backref='customer', lazy=True)

    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "phone": self.phone,
            "address": self.address,
            "created_at": self.created_at.isoformat() if self.created_at else None
        }

class Technician(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), unique=True, nullable=False)
    pin = db.Column(db.String(4), nullable=True) # Simple 4-digit PIN for technician login
    fcm_token = db.Column(db.String(255), nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "fcm_token": self.fcm_token,
            "created_at": self.created_at.isoformat() if self.created_at else None
        }

class Call(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    customer_id = db.Column(db.Integer, db.ForeignKey('customer.id'), nullable=False)
    call_type = db.Column(db.String(50), nullable=False)
    problem_description = db.Column(db.Text, nullable=False)
    priority = db.Column(db.String(50), nullable=False, default="Medium")
    technician_assigned = db.Column(db.String(255), nullable=True)
    status = db.Column(db.String(50), nullable=False, default="Pending")
    raw_input = db.Column(db.Text, nullable=True)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))

    updates = db.relationship('CallUpdate', backref='call', lazy=True, order_by='desc(CallUpdate.timestamp)')

    def to_dict(self, include_customer=False, include_updates=False):
        data = {
            "id": self.id,
            "customer_id": self.customer_id,
            "call_type": self.call_type,
            "problem_description": self.problem_description,
            "priority": self.priority,
            "technician_assigned": self.technician_assigned,
            "status": self.status,
            "raw_input": self.raw_input,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None
        }
        if include_customer and self.customer:
            data["customer"] = self.customer.to_dict()
        if include_updates:
            data["updates"] = [update.to_dict() for update in self.updates]
        return data

class CallUpdate(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    call_id = db.Column(db.Integer, db.ForeignKey('call.id'), nullable=False)
    note = db.Column(db.Text, nullable=False)
    status_change = db.Column(db.String(50), nullable=True)
    timestamp = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))

    def to_dict(self):
        return {
            "id": self.id,
            "call_id": self.call_id,
            "note": self.note,
            "status_change": self.status_change,
            "timestamp": self.timestamp.isoformat() if self.timestamp else None
        }
