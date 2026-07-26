from app import create_app
from models import db, Call, Customer

app = create_app()

with app.test_client() as client:
    print("Testing Assistant Endpoint...\n")
    
    # 1. Test resolving Alice's call
    print("--- Command: 'Resolve Alice call' ---")
    res1 = client.post('/api/assistant', json={'command': 'Resolve Alice call'})
    print("Status Code:", res1.status_code)
    print("Response JSON:", res1.get_json())
    print("\n")
    
    # 2. Test setting Bob's priority to high
    print("--- Command: 'Set Bob priority to high' ---")
    res2 = client.post('/api/assistant', json={'command': 'Set Bob priority to high'})
    print("Status Code:", res2.status_code)
    print("Response JSON:", res2.get_json())
    print("\n")
    
    # 3. Test changing status for Carol
    print("--- Command: 'Carol is waiting for parts' ---")
    res3 = client.post('/api/assistant', json={'command': 'Carol is waiting for parts'})
    print("Status Code:", res3.status_code)
    print("Response JSON:", res3.get_json())
    print("\n")
