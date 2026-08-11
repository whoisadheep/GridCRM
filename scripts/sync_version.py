#!/usr/bin/env python3
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).parent.parent

def main():
    pubspec_path = ROOT / "app" / "pubspec.yaml"
    version_json_path = ROOT / "public" / "version.json"

    # 1. Extract version from app/pubspec.yaml (Single Source of Truth)
    content = pubspec_path.read_text()
    match = re.search(r'^version:\s*([^\s+]+)', content, re.MULTILINE)
    if not match:
        print("❌ Could not find version in app/pubspec.yaml")
        return
    
    app_version = match.group(1).strip()
    print(f"📦 Single Source of Truth (app/pubspec.yaml): v{app_version}")

    # 2. Sync to public/version.json
    v_json = json.loads(version_json_path.read_text())
    old_version = v_json.get("latest_version")
    v_json["latest_version"] = app_version
    version_json_path.write_text(json.dumps(v_json, indent=2) + "\n")
    print(f"🔄 Synced public/version.json: {old_version} -> {app_version}")

    # 3. Deploy hosting automatically
    print("🚀 Hosting public/version.json to Firebase...")
    subprocess.run(["firebase", "deploy", "--only", "hosting"], cwd=ROOT, check=True)
    print("✨ Sync & Host Complete!")

if __name__ == "__main__":
    main()
