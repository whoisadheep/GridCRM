import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase (assuming default credentials or already initialized)
if not firebase_admin._apps:
    firebase_admin.initialize_app()

db = firestore.client()
owner_id = "Rudra"

collections = ["calls", "customers", "technicians", "admins", "call_updates"]

for collection_name in collections:
    print(f"Migrating {collection_name}...")
    docs = db.collection(collection_name).get()
    for doc in docs:
        if "ownerId" not in doc.to_dict():
            doc.reference.update({"ownerId": owner_id})
            print(f"Updated {doc.id} in {collection_name}")
        else:
            print(f"Skipped {doc.id} in {collection_name} (already has ownerId)")

print("Migration completed.")
