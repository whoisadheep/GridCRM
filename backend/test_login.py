import requests
import json
import time

BASE_URL = "http://127.0.0.1:5000/api"
print(f"Testing against {BASE_URL}...")

def test_admin_login():
    res = requests.post(f"{BASE_URL}/login", json={"role": "admin", "username": "admin", "password": "admin123"})
    print("Admin Login:", res.status_code, res.text)
    assert res.status_code == 200

def test_add_technician():
    res = requests.post(f"{BASE_URL}/technicians", json={"name": "TestTech1", "pin": "9999"})
    print("Add Technician:", res.status_code, res.text)
    assert res.status_code in [201, 400] # 400 if exists

def test_technician_login():
    res = requests.post(f"{BASE_URL}/login", json={"role": "technician", "name": "TestTech1", "pin": "9999"})
    print("Technician Login (Success):", res.status_code, res.text)
    assert res.status_code == 200

def test_technician_login_fail():
    res = requests.post(f"{BASE_URL}/login", json={"role": "technician", "name": "TestTech1", "pin": "1111"})
    print("Technician Login (Fail):", res.status_code, res.text)
    assert res.status_code == 401

def test_create_and_assign_call():
    payload = {
        "customer_name": "John Doe",
        "phone_number": "555-0001",
        "call_type": "Installation",
        "problem_description": "Need new AC",
        "priority": "Medium"
    }
    res = requests.post(f"{BASE_URL}/calls", json=payload)
    print("Create Call:", res.status_code, res.text)
    assert res.status_code == 201
    call_id = res.json().get("id")

    update_payload = {
        "note": "Assigned to tech",
        "technician_assigned": "TestTech1",
        "priority": "High"
    }
    res2 = requests.post(f"{BASE_URL}/calls/{call_id}/update", json=update_payload)
    print("Update Call:", res2.status_code, res2.text)
    assert res2.status_code == 200

if __name__ == "__main__":
    time.sleep(1)
    try:
        test_admin_login()
        test_add_technician()
        test_technician_login()
        test_technician_login_fail()
        test_create_and_assign_call()
        print("[SUCCESS] ALL TESTS PASSED!")
    except Exception as e:
        print("[ERROR] TEST FAILED:", e)
