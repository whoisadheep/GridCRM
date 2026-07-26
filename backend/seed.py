import os
from app import create_app
from models import db, Customer, Call

def seed_db():
    app = create_app()
    with app.app_context():
        # Test Data
        customers_data = [
            {"name": "Alice Smith", "phone": "555-0101", "address": "123 Maple St"},
            {"name": "Bob Johnson", "phone": "555-0102", "address": "456 Oak Ave"},
            {"name": "Carol Williams", "phone": "555-0103", "address": "789 Pine Rd"},
            {"name": "David Brown", "phone": "555-0104", "address": "321 Cedar Ln"},
            {"name": "Eva Davis", "phone": "555-0105", "address": "654 Elm St"},
            {"name": "Frank Miller", "phone": "555-0106", "address": "987 Birch Blvd"},
            {"name": "Grace Wilson", "phone": "555-0107", "address": "159 Spruce Ct"},
            {"name": "Henry Moore", "phone": "555-0108", "address": "753 Walnut Dr"},
            {"name": "Ivy Taylor", "phone": "555-0109", "address": "852 Chestnut Way"},
            {"name": "Jack Anderson", "phone": "555-0110", "address": "951 Ash Pl"}
        ]

        calls_data = [
            {"call_type": "Repair", "problem_description": "AC unit is blowing warm air", "priority": "High", "status": "Pending"},
            {"call_type": "Maintenance", "problem_description": "Annual furnace inspection", "priority": "Low", "status": "Pending"},
            {"call_type": "Installation", "problem_description": "Install new smart thermostat", "priority": "Medium", "status": "Pending"},
            {"call_type": "Repair", "problem_description": "Water leaking from under the sink", "priority": "High", "status": "In Progress"},
            {"call_type": "Diagnostic", "problem_description": "Strange noise coming from the refrigerator", "priority": "Medium", "status": "Pending"},
            {"call_type": "Repair", "problem_description": "Garage door won't open", "priority": "High", "status": "Pending"},
            {"call_type": "Maintenance", "problem_description": "Clean air ducts", "priority": "Low", "status": "Wait Parts"},
            {"call_type": "Repair", "problem_description": "Dishwasher not draining", "priority": "Medium", "status": "Pending"},
            {"call_type": "Installation", "problem_description": "Set up new home security cameras", "priority": "Medium", "status": "In Progress"},
            {"call_type": "Diagnostic", "problem_description": "Flickering lights in the living room", "priority": "High", "status": "Pending"}
        ]

        for i in range(10):
            c_data = customers_data[i]
            customer = Customer.query.filter_by(phone=c_data['phone']).first()
            if not customer:
                customer = Customer(name=c_data['name'], phone=c_data['phone'], address=c_data['address'])
                db.session.add(customer)
                db.session.commit()
            
            call_data = calls_data[i]
            call = Call(
                customer_id=customer.id,
                call_type=call_data['call_type'],
                problem_description=call_data['problem_description'],
                priority=call_data['priority'],
                status=call_data['status']
            )
            db.session.add(call)
        
        db.session.commit()
        print("Successfully seeded 10 test calls and customers!")

if __name__ == '__main__':
    seed_db()
