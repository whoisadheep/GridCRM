import requests

BASE_URL = "http://127.0.0.1:5000/api"

def test():
    print("Testing extraction (fallback since no valid gemini key)...")
    res = requests.post(f"{BASE_URL}/calls/extract", json={
        "raw_text": "camera not working at home +919876543210 please send someone asap"
    })
    print(res.json())

    print("\nCreating a call...")
    extracted = res.json()
    extracted["raw_input"] = "camera not working at home +919876543210 please send someone asap"
    extracted["customer_name"] = "John Doe"
    
    res2 = requests.post(f"{BASE_URL}/calls", json=extracted)
    print(res2.json())
    call_id = res2.json()["id"]

    print(f"\nGetting call {call_id}...")
    res3 = requests.get(f"{BASE_URL}/calls/{call_id}")
    print(res3.json())

    print(f"\nUpdating call {call_id}...")
    res4 = requests.post(f"{BASE_URL}/calls/{call_id}/update", json={
        "note": "Assigned to tech.",
        "status": "In Progress",
        "technician_assigned": "Bob"
    })
    print(res4.json())

    print("\nListing calls...")
    res5 = requests.get(f"{BASE_URL}/calls")
    print([c["id"] for c in res5.json()])

    print("\nListing technicians...")
    res6 = requests.get(f"{BASE_URL}/technicians")
    print(res6.json())

if __name__ == "__main__":
    test()
