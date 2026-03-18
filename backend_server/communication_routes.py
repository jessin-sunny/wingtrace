# Contacts handling, Group Handling, Message Handling
import os
from flask import Blueprint, request, jsonify
from firebase_admin import firestore
from deep_translator import GoogleTranslator
import smtplib
from email.mime.text import MIMEText

# Blueprint
comm_bp = Blueprint("communication", __name__)


# Firestore
fs = None

def init_firestore(client):
    global fs
    fs = client

# ===============================
# CONTACT MANAGEMENT
# ===============================
# Add contacts
@comm_bp.route("/addContact", methods=["POST"])
def add_contact():
    try:
        data = request.get_json(silent=True)

        if not data:
            return jsonify({"error": "Invalid JSON"}), 400

        name = data.get("name", "").strip()
        phone = data.get("phone", "").strip()
        email = data.get("email", "").strip()
        address = data.get("address", {})
        officer_id = data.get("officer_id", "").strip()

        # VALIDATION
        if not name:
            return jsonify({"error": "Name is required"}), 400

        if not phone:
            return jsonify({"error": "Phone number is required"}), 400

        if not officer_id:
            return jsonify({"error": "officer_id is required"}), 400

        # Basic phone validation
        if not phone.startswith("+91") or len(phone) < 10:
            return jsonify({"error": "Invalid phone number format"}), 400

        # Address fields
        ward = address.get("ward")
        locality = address.get("locality", "").strip()
        taluk = address.get("taluk", "").strip()
        district = address.get("district", "").strip()

        # CREATE CONTACT OBJECT
        contact_data = {
            "name": name,
            "phone": phone,
            "email": email,
            "address": {
                "ward": int(ward) if ward is not None else None,
                "locality": locality,
                "taluk": taluk,
                "district": district
            },
            "officer_id": officer_id,
            "createdAt": firestore.SERVER_TIMESTAMP
        }

        # STORE IN FIRESTORE
        doc_ref = fs.collection("contacts").document()
        doc_ref.set(contact_data)

        print(f"[CONTACT ADDED] {doc_ref.id} → {name}")

        return jsonify({
            "status": "SUCCESS",
            "contact_id": doc_ref.id
        }), 201

    except Exception as e:
        print(f"[ADD CONTACT ERROR] {e}")
        return jsonify({"error": str(e)}), 500

# Get Contact details by officer_id or ward or locality or taluk or district
@comm_bp.route("/getContacts", methods=["GET"])
def get_contacts():

    officer_id = request.args.get("officer_id")
    ward = request.args.get("ward")
    locality = request.args.get("locality")
    taluk = request.args.get("taluk")
    district = request.args.get("district")

    query = fs.collection("contacts")

    # Apply filters only if provided
    if officer_id:
        query = query.where("officer_id", "==", officer_id)

    if ward:
        query = query.where("address.ward", "==", int(ward))

    if locality:
        query = query.where("address.locality", "==", locality)

    if taluk:
        query = query.where("address.taluk", "==", taluk)

    if district:
        query = query.where("address.district", "==", district)

    docs = query.stream()

    contacts = []
    for doc in docs:
        data = doc.to_dict()
        data["contact_id"] = doc.id
        contacts.append(data)

    return jsonify(contacts), 200

# Remove Contacts
@comm_bp.route("/removeContact", methods=["POST"])
def remove_contact():
    try:
        data = request.get_json(silent=True)

        if not data:
            return jsonify({"error": "Invalid JSON"}), 400

        contact_id = data.get("contact_id", "").strip()
        officer_id = data.get("officer_id", "").strip()

        # VALIDATION
        if not contact_id:
            return jsonify({"error": "contact_id is required"}), 400

        if not officer_id:
            return jsonify({"error": "officer_id is required"}), 400

        # FETCH CONTACT
        contact_ref = fs.collection("contacts").document(contact_id)
        contact_doc = contact_ref.get()

        if not contact_doc.exists:
            return jsonify({"error": "Contact not found"}), 404

        contact_data = contact_doc.to_dict()

        # Ownership check
        if contact_data.get("officer_id") != officer_id:
            return jsonify({"error": "Unauthorized"}), 403

        # DELETE CONTACT
        contact_ref.delete()

        # REMOVE FROM ALL GROUPS
        groups_query = fs.collection("groups").where("officer_id", "==", officer_id).stream()

        affected_groups = 0

        for group_doc in groups_query:
            group_data = group_doc.to_dict()
            contacts = group_data.get("contacts", [])

            if contact_id in contacts:
                updated_contacts = [cid for cid in contacts if cid != contact_id]

                group_doc.reference.update({
                    "contacts": updated_contacts
                })

                affected_groups += 1

        print(f"[CONTACT REMOVED] {contact_id} removed from {affected_groups} groups")

        return jsonify({
            "status": "SUCCESS",
            "contact_id": contact_id,
            "removed_from_groups": affected_groups
        }), 200

    except Exception as e:
        print(f"[REMOVE CONTACT ERROR] {e}")
        return jsonify({"error": str(e)}), 500


# ===============================
# GROUP MANAGEMENT
# ===============================
# Create a group for officers with contacts
@comm_bp.route("/createGroup", methods=["POST"])
def create_group():
    try:
        data = request.get_json(silent=True)

        if not data:
            return jsonify({"error": "Invalid JSON"}), 400

        group_name = data.get("group_name", "").strip()
        contact_ids = data.get("contacts", [])
        officer_id = data.get("officer_id", "").strip()

        # VALIDATION
        if not group_name:
            return jsonify({"error": "group_name is required"}), 400

        if not officer_id:
            return jsonify({"error": "officer_id is required"}), 400

        if not isinstance(contact_ids, list):
            return jsonify({"error": "contacts must be a list"}), 400

        # Remove duplicates
        contact_ids = list(set(contact_ids))

        # VALIDATE CONTACT OWNERSHIP
        valid_contacts = []

        for cid in contact_ids:
            doc = fs.collection("contacts").document(cid).get()

            if not doc.exists:
                continue  # skip invalid contact

            contact_data = doc.to_dict()

            # Ensure contact belongs to same officer
            if contact_data.get("officer_id") == officer_id:
                valid_contacts.append(cid)

        # CREATE GROUP OBJECT
        group_data = {
            "group_name": group_name,
            "contacts": valid_contacts,
            "officer_id": officer_id,
            "createdAt": firestore.SERVER_TIMESTAMP
        }

        # STORE IN FIRESTORE
        doc_ref = fs.collection("groups").document()
        doc_ref.set(group_data)

        print(f"[GROUP CREATED] {doc_ref.id} → {group_name}")

        return jsonify({
            "status": "SUCCESS",
            "group_id": doc_ref.id,
            "contacts_added": len(valid_contacts)
        }), 201

    except Exception as e:
        print(f"[CREATE GROUP ERROR] {e}")
        return jsonify({"error": str(e)}), 500

# Get group details
@comm_bp.route("/getGroups", methods=["GET"])
def get_groups():
    try:
        officer_id = request.args.get("officer_id")

        if not officer_id:
            return jsonify({"error": "officer_id is required"}), 400

        # Fetch groups
        query = fs.collection("groups").where("officer_id", "==", officer_id)
        docs = query.stream()

        groups = []

        for doc in docs:
            data = doc.to_dict()
            contact_ids = data.get("contacts", [])

            members = []

            # Fetch contact details for each contact_id
            for cid in contact_ids:
                contact_doc = fs.collection("contacts").document(cid).get()

                if contact_doc.exists:
                    cdata = contact_doc.to_dict()

                    members.append({
                        "contact_id": cid,
                        "name": cdata.get("name"),
                        "phone": cdata.get("phone"),
                        "email": cdata.get("email"),
                        "address": cdata.get("address", {})
                    })

            groups.append({
                "group_id": doc.id,
                "group_name": data.get("group_name"),
                "members": members,
                "member_count": len(members)
            })

        return jsonify(groups), 200

    except Exception as e:
        print(f"[GET GROUPS ERROR] {e}")
        return jsonify({"error": str(e)}), 500
    
# adding contacts to group
@comm_bp.route("/addToGroup", methods=["POST"])
def add_to_group():
    try:
        data = request.get_json(silent=True)

        if not data:
            return jsonify({"error": "Invalid JSON"}), 400

        group_id = data.get("group_id", "").strip()
        contact_ids = data.get("contacts", [])
        officer_id = data.get("officer_id", "").strip()

        # VALIDATION
        if not group_id:
            return jsonify({"error": "group_id is required"}), 400

        if not officer_id:
            return jsonify({"error": "officer_id is required"}), 400

        if not isinstance(contact_ids, list):
            return jsonify({"error": "contacts must be a list"}), 400

        # FETCH GROUP
        group_ref = fs.collection("groups").document(group_id)
        group_doc = group_ref.get()

        if not group_doc.exists:
            return jsonify({"error": "Group not found"}), 404

        group_data = group_doc.to_dict()

        # Check ownership
        if group_data.get("officer_id") != officer_id:
            return jsonify({"error": "Unauthorized"}), 403

        existing_contacts = group_data.get("contacts", [])

        # VALIDATE CONTACTS
        valid_contacts = []

        for cid in contact_ids:
            doc = fs.collection("contacts").document(cid).get()

            if not doc.exists:
                continue

            contact_data = doc.to_dict()

            # Ensure same officer
            if contact_data.get("officer_id") == officer_id:
                valid_contacts.append(cid)

        # MERGE + REMOVE DUPLICATES
        updated_contacts = list(set(existing_contacts + valid_contacts))

        # UPDATE GROUP
        group_ref.update({
            "contacts": updated_contacts
        })

        print(f"[GROUP UPDATED] {group_id} +{len(valid_contacts)} contacts")

        return jsonify({
            "status": "SUCCESS",
            "group_id": group_id,
            "total_contacts": len(updated_contacts)
        }), 200

    except Exception as e:
        print(f"[ADD TO GROUP ERROR] {e}")
        return jsonify({"error": str(e)}), 500

# Remove Contacts from Group
@comm_bp.route("/removeFromGroup", methods=["POST"])
def remove_from_group():
    try:
        data = request.get_json(silent=True)

        if not data:
            return jsonify({"error": "Invalid JSON"}), 400

        group_id = data.get("group_id", "").strip()
        contact_ids = data.get("contacts", [])
        officer_id = data.get("officer_id", "").strip()

        # VALIDATION
        if not group_id:
            return jsonify({"error": "group_id is required"}), 400

        if not officer_id:
            return jsonify({"error": "officer_id is required"}), 400

        if not isinstance(contact_ids, list):
            return jsonify({"error": "contacts must be a list"}), 400

        # FETCH GROUP
        group_ref = fs.collection("groups").document(group_id)
        group_doc = group_ref.get()

        if not group_doc.exists:
            return jsonify({"error": "Group not found"}), 404

        group_data = group_doc.to_dict()

        # Ownership check
        if group_data.get("officer_id") != officer_id:
            return jsonify({"error": "Unauthorized"}), 403

        existing_contacts = group_data.get("contacts", [])

        # REMOVE CONTACTS (MULTIPLE)
        updated_contacts = [
            cid for cid in existing_contacts if cid not in contact_ids
        ]

        removed_count = len(existing_contacts) - len(updated_contacts)

        # DELETE GROUP IF EMPTY
        if len(updated_contacts) == 0:
            group_ref.delete()
            print(f"[GROUP DELETED] {group_id} (empty)")

            return jsonify({
                "status": "SUCCESS",
                "group_id": group_id,
                "removed_count": removed_count,
                "group_deleted": True
            }), 200

        # UPDATE GROUP
        group_ref.update({
            "contacts": updated_contacts
        })

        print(f"[GROUP UPDATED] {group_id} -{removed_count} contacts")

        return jsonify({
            "status": "SUCCESS",
            "group_id": group_id,
            "removed_count": removed_count,
            "remaining_contacts": len(updated_contacts),
            "group_deleted": False
        }), 200

    except Exception as e:
        print(f"[REMOVE FROM GROUP ERROR] {e}")
        return jsonify({"error": str(e)}), 500


# ===============================
# MESSAGE GENERATION (HYBRID)
# ===============================
def translate_to_malayalam(text):
    try:
        if not text:
            return ""

        # Handle long text safely (split if needed)
        if len(text) > 4000:
            chunks = [text[i:i+4000] for i in range(0, len(text), 4000)]
            translated_chunks = []

            for chunk in chunks:
                translated = GoogleTranslator(
                    source='auto',
                    target='ml'
                ).translate(chunk)
                translated_chunks.append(translated)

            return " ".join(translated_chunks)

        # Normal case
        return GoogleTranslator(
            source='auto',
            target='ml'
        ).translate(text)

    except Exception as e:
        print(f"[TRANSLATION ERROR] {e}")
        return text  # fallback to original

@comm_bp.route("/generateMessage", methods=["POST"])
def generate_message():
    try:
        data = request.get_json(silent=True)

        if not data:
            return jsonify({"error": "Invalid JSON"}), 400

        message_type = data.get("message_type")
        officer_id = data.get("officer_id")
        species_name = data.get("species_name")
        text_field = data.get("text", "").strip()
        include_malayalam = data.get("include_malayalam", False)

        if not message_type:
            return jsonify({"error": "message_type required"}), 400

        if not officer_id:
            return jsonify({"error": "officer_id required"}), 400

        # FETCH OFFICER
        officer_doc = fs.collection("users").document(officer_id).get()

        if not officer_doc.exists:
            return jsonify({"error": "Officer not found"}), 404

        officer = officer_doc.to_dict()

        officer_name = officer.get("name", "Officer")
        officer_phone = officer.get("phoneno", "")
        officer_email = officer.get("emailid", "")

        english_msg = ""
        malayalam_msg = None

        # ===============================
        # GENERAL
        # ===============================
        if message_type == "General":

            if not text_field:
                return jsonify({"error": "Text required for General message"}), 400

            english_msg = f"""🛈 INFORMATION

Message:
{text_field}

Reported By:
{officer_name}

Contact:
Phone: {officer_phone}
Email: {officer_email}
"""

            if include_malayalam:
                mal_text = translate_to_malayalam(text_field)

                malayalam_msg = f"""🛈 വിവരങ്ങൾ

സന്ദേശം:
{mal_text}

റിപ്പോർട്ട് ചെയ്തത്:
{officer_name}

ബന്ധപ്പെടുക:
ഫോൺ: {officer_phone}
ഇമെയിൽ: {officer_email}
"""

        # ===============================
        # WARNING / ALERT
        # ===============================
        elif message_type in ["Warning", "Alert"]:

            if not species_name:
                return jsonify({"error": "species_name required"}), 400

            doc_id = species_name.strip().lower().replace(" ", "_")
            species_doc = fs.collection("categories").document(doc_id).get()

            if not species_doc.exists:
                return jsonify({"error": "Species not found"}), 404

            species = species_doc.to_dict()

            common_name = species.get("common_name", species_name)
            risk = species.get("default_risk", "Unknown")

            diseases = species.get("diseases") or species.get("damage_symptoms") or []
            actions = species.get("public_actions", [])
            controls = species.get("control_methods", [])

            disease_text = "\n".join(diseases[:3]) if diseases else "N/A"
            action_text = "\n".join([a.get("title", "") for a in actions[:3]]) if actions else "N/A"
            control_text = "\n".join([c.get("name", "") for c in controls[:3]]) if controls else "N/A"

            # WARNING
            if message_type == "Warning":

                english_msg = f"""⚠️ WARNING

Species Detected: {common_name}

Risk Level: {risk}

Possible Issues:
{disease_text}

Recommended Actions:
{action_text}

Reported By:
{officer_name}

Contact:
Phone: {officer_phone}
Email: {officer_email}
"""

                if include_malayalam:
                    mal_combined = translate_to_malayalam(f"{disease_text}\n{action_text}")
                    mal_parts = mal_combined.split("\n")

                    mal_disease = "\n".join(mal_parts[:len(diseases[:3])])
                    mal_action = "\n".join(mal_parts[len(diseases[:3]):])

                    malayalam_msg = f"""⚠️ മുന്നറിയിപ്പ്

കണ്ടെത്തിയ ജീവി: {common_name}

റിസ്ക് നില: {risk}

സാധ്യമായ പ്രശ്നങ്ങൾ:
{mal_disease}

പരിഹാര നടപടികൾ:
{mal_action}

റിപ്പോർട്ട് ചെയ്തത്:
{officer_name}

ബന്ധപ്പെടുക:
ഫോൺ: {officer_phone}
ഇമെയിൽ: {officer_email}
"""

            # ALERT
            elif message_type == "Alert":

                english_msg = f"""🚨 ALERT

High Risk Detection: {common_name}

Potential Threat:
{disease_text}

Immediate Action Required:
{control_text}

Reported By:
{officer_name}

Contact:
Phone: {officer_phone}
Email: {officer_email}
"""

                if include_malayalam:
                    mal_combined = translate_to_malayalam(f"{disease_text}\n{control_text}")
                    mal_parts = mal_combined.split("\n")

                    mal_disease = "\n".join(mal_parts[:len(diseases[:3])])
                    mal_control = "\n".join(mal_parts[len(diseases[:3]):])

                    malayalam_msg = f"""🚨 അലർട്ട്

ഉയർന്ന അപകടസാധ്യത: {common_name}

ഭീഷണി:
{mal_disease}

ഉടൻ ചെയ്യേണ്ടത്:
{mal_control}

റിപ്പോർട്ട് ചെയ്തത്:
{officer_name}

ബന്ധപ്പെടുക:
ഫോൺ: {officer_phone}
ഇമെയിൽ: {officer_email}
"""

        else:
            return jsonify({"error": "Invalid message_type"}), 400

        # ===============================
        # ADDITIONAL NOTES
        # ===============================
        if text_field and message_type != "General":
            english_msg += f"\nAdditional Notes:\n{text_field}"

            if include_malayalam and malayalam_msg:
                mal_extra = translate_to_malayalam(text_field)
                malayalam_msg += f"\nകൂടുതൽ വിവരങ്ങൾ:\n{mal_extra}"

        # ===============================
        # RESPONSE
        # ===============================
        response = {
            "status": "SUCCESS",
            "message": {
                "english": english_msg
            }
        }

        if include_malayalam:
            response["message"]["malayalam"] = malayalam_msg

        return jsonify(response), 200

    except Exception as e:
        print(f"[GENERATE MESSAGE ERROR] {e}")
        return jsonify({"error": str(e)}), 500


# ===============================
# EMAIL SENDING
# ===============================
def send_email(to_email, subject, message):
    sender_email = os.environ.get("EMAIL_ID")
    app_password = os.environ.get("EMAIL_PASS")

    msg = MIMEText(message)
    msg["Subject"] = subject
    msg["From"] = sender_email
    msg["To"] = to_email

    with smtplib.SMTP_SSL("smtp.gmail.com", 465) as server:
        server.login(sender_email, app_password)
        server.send_message(msg)


# ===============================
# SEND MESSAGE
# ===============================
@comm_bp.route("/sendMessage", methods=["POST"])
def send_message():
    try:
        data = request.get_json(silent=True)

        if not data:
            return jsonify({"error": "Invalid JSON"}), 400

        officer_id = data.get("officer_id")
        message_data = data.get("message", {})
        contact_ids = data.get("contacts", [])
        group_ids = data.get("groups", [])
        send_email_flag = data.get("email", False)

        if not officer_id:
            return jsonify({"error": "officer_id required"}), 400

        english_msg = message_data.get("english")
        malayalam_msg = message_data.get("malayalam")

        if not english_msg:
            return jsonify({"error": "English message required"}), 400

        # MERGE CONTACT IDS
        all_contact_ids = set(contact_ids)

        for gid in group_ids:
            group_doc = fs.collection("groups").document(gid).get()

            if group_doc.exists:
                group_data = group_doc.to_dict()

                # Ownership check
                if group_data.get("officer_id") != officer_id:
                    continue

                all_contact_ids.update(group_data.get("contacts", []))

        # FETCH CONTACTS
        contacts = []

        for cid in all_contact_ids:
            doc = fs.collection("contacts").document(cid).get()

            if doc.exists:
                cdata = doc.to_dict()

                if cdata.get("officer_id") == officer_id:
                    contacts.append({
                        "name": cdata.get("name"),
                        "phone": cdata.get("phone"),
                        "email": cdata.get("email")
                    })

        # PREPARE MESSAGE
        final_msg = english_msg
        if malayalam_msg:
            final_msg += "\n\n" + malayalam_msg

        # SEND EMAILS
        email_sent = 0

        if send_email_flag:
            for c in contacts:
                if c["email"]:
                    try:
                        send_email(c["email"], "WingTrace Alert", final_msg)
                        email_sent += 1
                    except Exception as e:
                        print(f"[EMAIL FAILED] {c['email']} → {e}")

        return jsonify({
            "status": "SUCCESS",
            "total_contacts": len(contacts),
            "email_sent": email_sent
        }), 200

    except Exception as e:
        print(f"[SEND MESSAGE ERROR] {e}")
        return jsonify({"error": str(e)}), 500