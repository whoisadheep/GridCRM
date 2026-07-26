import os
import re
import json
import google.generativeai as genai

SYSTEM_PROMPT = """You are a data extraction assistant for a CCTV/IT service call CRM.
Given a free-text description of a customer call (often in Hinglish or casual English), extract the following fields and return ONLY valid JSON, no markdown formatting, no explanation:

{
  "customer_name": string or null,
  "phone_number": string or null (digits only, no spaces/dashes),
  "call_type": one of ["Service", "Installation", "AMC", "Sales", "Other"],
  "problem_description": string (rewrite the issue clearly and concisely),
  "priority": one of ["Low", "Medium", "High"]
}

Rules:
- If phone number isn't clearly present, set it to null.
- Infer call_type from context (e.g. "camera not working" = Service, "want new cameras installed" = Installation, "yearly maintenance" = AMC).
- Infer priority from urgency cues (words like "not working", "urgent", "down", "asap" = High; vague requests = Low; default to Medium if unclear).
- Do not invent information not present in the text."""

def setup_gemini():
    api_key = os.environ.get("GEMINI_API_KEY")
    if api_key:
        genai.configure(api_key=api_key)
        return True
    return False

def clean_json_string(raw_str):
    # Strip any markdown json fences
    raw_str = raw_str.strip()
    if raw_str.startswith("```json"):
        raw_str = raw_str[7:]
    if raw_str.startswith("```"):
        raw_str = raw_str[3:]
    if raw_str.endswith("```"):
        raw_str = raw_str[:-3]
    return raw_str.strip()

def fallback_extract(raw_text):
    # Regex extract a phone number if possible
    phone_match = re.search(r'\+?\d[\d\s-]{8,14}\d', raw_text)
    phone_number = None
    if phone_match:
        phone_number = re.sub(r'[^\d]', '', phone_match.group(0))

    return {
        "customer_name": None,
        "phone_number": phone_number,
        "call_type": "Other",
        "problem_description": raw_text,
        "priority": "Medium"
    }

def extract_call_info(raw_text):
    if not setup_gemini():
        return fallback_extract(raw_text)

    try:
        model = genai.GenerativeModel('gemini-flash-lite-latest', system_instruction=SYSTEM_PROMPT)
        response = model.generate_content(raw_text)
        json_str = clean_json_string(response.text)
        data = json.loads(json_str)

        # Basic validation
        if not isinstance(data, dict):
            raise ValueError("Response is not a JSON object")

        return {
            "customer_name": data.get("customer_name"),
            "phone_number": data.get("phone_number"),
            "call_type": data.get("call_type", "Other"),
            "problem_description": data.get("problem_description", raw_text),
            "priority": data.get("priority", "Medium")
        }
    except Exception as e:
        print(f"Gemini extraction failed: {e}")
        return fallback_extract(raw_text)

def process_command(raw_text):
    if not setup_gemini():
        return None

    try:
        system_prompt = """You are an AI assistant controlling a CRM app. The user will give you a natural language command in English, Hindi, or Hinglish (e.g. "resolve alice call" or "jon ki priority high kar do" or "naya call banao"). 
Extract the intent and return ONLY valid JSON:
{
  "action": "update_call" | "create_call" | "unknown",
  "target_name": "string (name of customer if updating)",
  "customer_name": "string (name of customer if creating)",
  "phone": "string (phone number if creating, digits only)",
  "reply": "If action is unknown, write a short polite response (in the language the user spoke) explaining you only manage CRM tickets.",
  "updates": {
    "problem_description": "string (issue description if creating)",
    "status": "optional string (e.g. 'Resolved', 'Pending')",
    "priority": "optional string (e.g. 'High', 'Medium', 'Low')",
    "technician_assigned": "optional string (name of technician to assign)"
  }
}
"""
        model = genai.GenerativeModel('gemini-2.5-flash-lite', system_instruction=system_prompt)
        response = model.generate_content(raw_text)
        json_str = clean_json_string(response.text)
        return json.loads(json_str)
    except Exception as e:
        print(f"Command processing failed: {e}")
        return None
