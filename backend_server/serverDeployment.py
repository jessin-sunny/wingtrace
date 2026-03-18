import wave
import threading
from datetime import datetime, timedelta, timezone
from flask import Flask, request, jsonify
import firebase_admin
from firebase_admin import credentials, db as rtdb
import os, json, time
from firebase_admin import firestore
import uuid
<<<<<<< HEAD:backend_database/serverDeployment.py
=======
from threading import Lock
from google.cloud.firestore_v1 import FieldFilter
from flask_sock import Sock
from threading import Lock
from supabase import create_client
from google.api_core.exceptions import DeadlineExceeded
from gradio_client import Client, handle_file
from communication_routes import comm_bp

>>>>>>> origin/main:backend_server/serverDeployment.py

app = Flask(__name__)

# firebase setup
firebase_key = json.loads(os.environ["FIREBASE_KEY"])

cred = credentials.Certificate(firebase_key)

firebase_admin.initialize_app(cred, {
    "databaseURL": "https://wingtrace-ead16-default-rtdb.firebaseio.com/"
})

fs = firestore.client()   # Firestore client

<<<<<<< HEAD:backend_database/serverDeployment.py

=======
# IMPORT ROUTES (AFTER INIT)
from communication_routes import comm_bp, init_firestore

# Inject Firestore into routes
init_firestore(fs)

# Register blueprint
app.register_blueprint(comm_bp)

# Supabase
SUPABASE_URL = os.environ["SUPABASE_URL"]
SUPABASE_KEY = os.environ["SUPABASE_SERVICE_ROLE_KEY"]

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
# HuggingFace audio model
hf_client = Client("wingtrace/audiomodel")


devices_lock = Lock()   # Thread Safety
>>>>>>> origin/main:backend_server/serverDeployment.py
# ===============================
# CONFIG
# ===============================
# Railway provides PORT via environment variable
PORT = int(os.environ.get("PORT", 5000))

# Persistent volume path (Railway-safe)
AUDIO_DIR = os.environ.get("AUDIO_DIR", "recordings")
os.makedirs(AUDIO_DIR, exist_ok=True)

# Audio config (ESP32 must match)
SAMPLE_RATE = 16000
CHANNELS = 1
SAMPLE_WIDTH = 2  # 16-bit PCM
BYTES_PER_SECOND = SAMPLE_RATE * SAMPLE_WIDTH  # 32000

# ===============================
# GLOBAL STATE (in-memory)
# ===============================

audio_buffer = bytearray()
recording = False

devices = {}           # device status & weather
device_commands = {}   # pending commands

# ===============================
<<<<<<< HEAD:backend_database/serverDeployment.py
=======
# AUDIO STATE (IN-MEMORY)
# ===============================

audio_buffers = {}     # deviceId -> bytearray
audio_locks = {}       # deviceId -> Lock


CHUNK_SECONDS = 300
CHUNK_BYTES = BYTES_PER_SECOND * CHUNK_SECONDS
SAMPLE_RATE = 16000
CHANNELS = 1
SAMPLE_WIDTH = 2  # int16

# ===============================
# RENDER SAFETY CHECK
# ===============================
@app.route('/')
def health_check():
    return "OK", 200

# ===============================
>>>>>>> origin/main:backend_server/serverDeployment.py
# DEVICE HEARTBEAT
# ===============================

@app.route('/alive', methods=['POST'])
def alive():
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"error": "No JSON received"}), 400

    device_id = data.get("deviceId", "").strip()
    if not device_id:
        return jsonify({"error": "deviceId missing"}), 400

    devices.setdefault(device_id, {})
    devices[device_id].update({
        "status": "ONLINE",
        "last_seen": int(time.time()),
        "user_connected": True
    })

<<<<<<< HEAD:backend_database/serverDeployment.py
    print(f"[ALIVE] {device_id} ONLINE")
=======
    # Firebase update
    rtdb.reference(f"devices/{device_id}/status").update({
        "isOnline": True,
        "factoryReset": False,
        "lastSeen": now,
        "batteryLevel": battery_level,
        "networkStrength": signal_quality
    })

    print(f"[ALIVE] {device_id} | RSSI={rssi} | SIGNAL={signal_quality} | Battery Level={battery_level}")
>>>>>>> origin/main:backend_server/serverDeployment.py
    return jsonify({"message": "ALIVE received"}), 200


@app.route('/devices', methods=['GET'])
def list_devices():
    return jsonify(devices), 200

# ===============================
# DEVICE STATUS
# ===============================

@app.route('/status', methods=['POST'])
def update_status():
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"error": "No JSON"}), 400

    device_id = data.get("deviceId", "").strip()
    if not device_id:
        return jsonify({"error": "deviceId missing"}), 400

    status_data = {
        "isOnline": data.get("isOnline", True),
        "lastSeen": int(time.time()),   # timestamp
        "batteryLevel": data.get("batteryLevel"),
        "isReset": data.get("isReset", False),
        "networkStrength": data.get("networkStrength")
    }

    fs.reference(f"devices/{device_id}/status").set(status_data)

    return jsonify({
        "message": "status stored",
        "status": status_data
    }), 200

@app.route('/status/<device_id>', methods=['GET'])
def get_status(device_id):
    ref = fs.reference(f"devices/{device_id.strip()}/status")
    data = ref.get()

    if not data:
        return jsonify({"error": "No status data"}), 404

    return jsonify(data), 200


# ===============================
# WEATHER DATA
# ===============================

@app.route('/weather', methods=['POST'])
def weather():
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"error": "No JSON"}), 400

    device_id = data.get("deviceId", "").strip()
    if not device_id:
        return jsonify({"error": "deviceId missing"}), 400

    timestamp = int(time.time())

    weather_data = {
        "temperature": data.get("temperature"),
        "humidity": data.get("humidity"),
        "updated_at": timestamp
    }

    fs.reference(f"devices/{device_id}/weather").set(weather_data)

    print(f"[WEATHER] {device_id} → {weather_data}")

    return jsonify({"message": "weather stored in firebase"}), 200


@app.route('/weather/<device_id>', methods=['GET'])
def get_weather(device_id):
    ref = fs.reference(f"devices/{device_id.strip()}/weather")
    data = ref.get()

    if not data:
        return jsonify({"error": "No data"}), 404

    return jsonify(data), 200


# ===============================
# SPECIES DATA
# ===============================

def get_species_images(category, species):

    bucket = supabase.storage.from_("categories")

    species_id = species.strip().lower().replace(" ", "_")

    folder = f"{category}/{species_id}"

    images = []

    try:

        res = bucket.list(folder)

        if res:
            for file in res:

                name = file.get("name")

                if name:
                    path = f"{folder}/{name}"

                    url = bucket.get_public_url(path)

                    images.append(url)

    except Exception as e:
        print(f"[IMAGE LIST ERROR] {e}")

    return images


@app.route("/category/<doc_id>", methods=["GET"])
def get_category(doc_id):

    doc_id = doc_id.strip().lower().replace(" ", "_")

    try:

        doc = fs.collection("categories").document(doc_id).get()

        if not doc.exists:
            return jsonify({"error": "Category not found"}), 404

        data = doc.to_dict()

        category = data.get("category")

        if not category:
            return jsonify({"error": "Category field missing"}), 500

        # fetch images from Supabase
        images = get_species_images(category, doc_id)

        data["images"] = images

        return jsonify(data), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ===============================
# CONNECTION CONTROL
# ===============================
@app.route("/startSetup", methods=["POST"])
def start_setup():
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"error": "Invalid JSON"}), 400
    owner_id = data.get("userId")
    

    if not owner_id:
        return jsonify({"error": "Missing userId"}), 400

    setup_token =  uuid.uuid4().hex
    now = datetime.now(timezone.utc)

    fs.collection("setupSessions").document(setup_token).set({
        "setupToken": setup_token,
        "ownerId": owner_id,
        "deviceId": None,
        "status": "WAITING",
        "createdAt": firestore.SERVER_TIMESTAMP,
        "expiresAt": now + timedelta(minutes=5)
    })

    return jsonify({
        "setupToken": setup_token,
        "expiresIn": 300
    }), 200

def expire_token_if_needed(token_ref, token_data):
    if token_data.get("status") != "WAITING":
        return False

    expires_at = token_data.get("expiresAt")
    if not expires_at:
        return False

    now = datetime.now(timezone.utc)

    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)

    if expires_at < now:
        token_ref.update({"status": "EXPIRED"})
        return True

    return False

@app.route("/onBoard", methods=["POST"])
def onBoard_device():
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"error": "Invalid JSON"}), 400


    device_id  = data.get("deviceId")
    owner_id   = data.get("userId")
    setupToken = data.get("setupToken")

    if not device_id or not owner_id or not setupToken:
        return jsonify({"error": "Missing fields"}), 400

    # 🔹 Validate setup token
    token_ref = fs.collection("setupSessions").document(setupToken)
    token_doc = token_ref.get()

    if not token_doc.exists:
        return jsonify({"error": "Invalid setup token"}), 403

    token_data = token_doc.to_dict()

    if expire_token_if_needed(token_ref, token_data):
        return jsonify({"error": "Setup token expired"}), 403

    if token_data["status"] != "WAITING":
        return jsonify({"error": "Token already used"}), 403

    if token_data["ownerId"] != owner_id:
        return jsonify({"error": "Token-owner mismatch"}), 403

    # 🔹 Validate device
    device_ref = fs.collection("devices").document(device_id)
    device_doc = device_ref.get()

    if not device_doc.exists:
        return jsonify({"error": "Unknown device"}), 404

    if device_doc.to_dict().get("ownerId"):
        return jsonify({"error": "Device already owned"}), 403

    # 🔹 Assign ownership
    device_ref.set({
        "ownerId": owner_id,
        "status": "CONNECTED"
    }, merge=True)

    # 🔹 Update user
    fs.collection("users").document(owner_id).set({
        "devices": firestore.ArrayUnion([device_id])
    }, merge=True)

    # 🔹 Mark token as USED
    token_ref.update({
        "status": "USED",
        "deviceId": device_id
    })

    print(f"[ONBOARD] {device_id} → {owner_id}")

<<<<<<< HEAD:backend_database/serverDeployment.py
=======
    device_commands.pop(device_id, None)  # clear stale commands

    rtdb.reference(f"devices/{device_id}/status").update({
        "isOnline": True,
        "factoryReset": False
    })

>>>>>>> origin/main:backend_server/serverDeployment.py
    return jsonify({
        "status": "SUCCESS",
        "deviceId": device_id
    }), 200


@app.route('/disconnect', methods=['POST'])
def disconnect():
    data = request.get_json(silent=True)
    device_id = data.get("deviceId", "").strip() if data else ""

    if not device_id or device_id not in devices:
        return jsonify({"error": "Invalid deviceId"}), 400

    devices[device_id]["status"] = "OFFLINE"
    devices[device_id]["user_connected"] = False

    print(f"[DISCONNECT] {device_id}")
    return jsonify({"message": "Device disconnected"}), 200


# ===============================
# COMMAND CHANNEL
# ===============================
<<<<<<< HEAD:backend_database/serverDeployment.py

@app.route("/reset", methods=["POST"])
def reset_device():
=======
# Factory Reset
@app.route("/factoryReset", methods=["POST"])
def factoryReset():
>>>>>>> origin/main:backend_server/serverDeployment.py
    data = request.get_json(silent=True)
    device_id = data.get("deviceId", "").strip() if data else ""

    if not device_id:
        return jsonify({"error": "deviceId required"}), 400

    device_commands[device_id] = "RESET"
    print(f"[RESET] queued for {device_id}")
    return jsonify({"status": "RESET queued"}), 200


@app.route("/command", methods=["GET"])
def get_command():
    device_id = request.args.get("deviceId", "").strip()
<<<<<<< HEAD:backend_database/serverDeployment.py
    cmd = device_commands.get(device_id, "NO_COMMAND")

    if cmd != "NO_COMMAND":
        device_commands[device_id] = "NO_COMMAND"
        print(f"[CMD SENT] {device_id} → {cmd}")

    return cmd, 200

=======
    if not device_id:
        return "NO_COMMAND", 200

    try:
        device_doc = fs.collection("devices").document(device_id).get(timeout=5)
    except DeadlineExceeded:
        print("[FIRESTORE TIMEOUT]")
        return "NO_COMMAND", 200
    except Exception as e:
        print(f"[FIRESTORE ERROR] {e}")
        return "NO_COMMAND", 200

    if not device_doc.exists:
        return "NO_COMMAND", 200

    if device_doc.to_dict().get("status") != "CONNECTED":
        return "NO_COMMAND", 200
    
    status = rtdb.reference(f"devices/{device_id}/status").get()
    if not status or not status.get("isOnline"):
        return "NO_COMMAND", 200


    cmd_obj = device_commands.pop(device_id, None)
    if not cmd_obj:
        return "NO_COMMAND", 200

    command = cmd_obj["command"]
    user_id = cmd_obj.get("userId")   # stored during /reset

    if command == "RESET":
        # RTDB: mark offline + reset
        rtdb.reference(f"devices/{device_id}/status").update({
            "isOnline": False,
            "factoryReset": True
        })

        # Firestore: clear ownership
        if user_id:
            fs.collection("devices").document(device_id).update({
                "ownerId": firestore.DELETE_FIELD,
                "status": "DISCONNECTED"
            })

            fs.collection("users").document(user_id).update({
                "devices": firestore.ArrayRemove([device_id])
            })

        print(f"[CMD SENT] {device_id} → RESET (ownership cleared)")

    return command, 200


>>>>>>> origin/main:backend_server/serverDeployment.py
# ===============================
# ADMIN CONTROL
# ===============================
# ADMIN: Manufacture a new device and add information to database
@app.route("/addDevice", methods=["POST"])
def add_device():
    data = request.get_json(silent=True)

    if not data:
        return jsonify({"error": "Invalid JSON"}), 400

    device_id = data.get("deviceId")
    device_name = data.get("deviceName")
    firmware = data.get("firmwareVersion")
    createdAt = data.get("createdAt")

    if not device_id or not device_name or not firmware:
        return jsonify({"error": "Missing fields"}), 400

    device_ref = fs.collection("devices").document(device_id)

    # Prevent overwriting existing device
    if device_ref.get().exists:
        return jsonify({"error": "Device already exists"}), 409

    device_ref.set({
        "deviceName": device_name,
        "firmwareVersion": firmware,
        "status": "DISCONNECTED",
        "createdAt": createdAt,
    })

    print(f"[ADD DEVICE] {device_id} registered")

    return jsonify({
        "status": "SUCCESS",
        "deviceId": device_id
    }), 201

def parse_json_fields(data, fields):

    for f in fields:
        if f in data:
            try:
                data[f] = json.loads(data[f])
            except:
                pass

# ADMIN: Add new species information to database
@app.route("/insertCategory", methods=["POST"])
def insert_category():

    data = request.form.to_dict()

    category = data.get("category")
    if not category:
        return jsonify({"error": "category field required"}), 400


    mosquito_fields = [
        "name","category","default_risk","diseases","bite_time","common_name","scientific_name",
        "breeding_sites","subspecies","risk_radius",
        "public_actions","control_methods"
    ]

    pest_fields = [
        "name","category","default_risk","crops_affected","active_period",
        "habitat","damage_symptoms","subspecies","common_name","scientific_name",
        "public_actions","control_methods"
    ]


    if category == "mosquito":
        required_fields = mosquito_fields
    elif category == "pest":
        required_fields = pest_fields
    else:
        return jsonify({"error": "category must be 'mosquito' or 'pest'"}), 400


    # Convert JSON string fields to Python objects
    parse_json_fields(data, [
        "diseases",
        "bite_time",
        "breeding_sites",
        "subspecies",
        "public_actions",
        "control_methods",
        "crops_affected",
        "active_period",
        "habitat",
        "damage_symptoms"
    ])


    missing = [f for f in required_fields if f not in data]
    if missing:
        return jsonify({
            "error": "Missing required fields",
            "missing": missing
        }), 400


    name = data["name"]
    doc_id = name.strip().lower().replace(" ", "_")

    doc_ref = fs.collection("categories").document(doc_id)

    if doc_ref.get().exists:
        return jsonify({"error": "Species already exists"}), 409


    # ============================
    # IMAGE HANDLING (0–N images)
    # ============================

    files = request.files.getlist("images")

    for file in files:

        if file and file.filename != "":
            try:

                image_url = upload_category_image_to_supabase(
                    file,
                    category,
                    name
                )

            except Exception as e:
                return jsonify({"error": f"Image upload failed: {str(e)}"}), 500


    data["createdAt"] = firestore.SERVER_TIMESTAMP


    try:

        doc_ref.set(data)

        print(f"[CATEGORY INSERTED] {doc_id}")

        return jsonify({
            "status": "SUCCESS",
            "documentId": doc_id
        }), 201

    except Exception as e:

        return jsonify({"error": str(e)}), 500

# ADMIN: Update species information to database
@app.route("/updateCategory", methods=["POST"])
def update_category():

    data = request.form.to_dict()

    name = data.get("name")
    if not name:
        return jsonify({"error": "name required"}), 400


    doc_id = name.strip().lower().replace(" ", "_")

    doc_ref = fs.collection("categories").document(doc_id)
    doc = doc_ref.get()

    if not doc.exists:
        return jsonify({"error": "Category not found"}), 404


    existing_data = doc.to_dict()

    category = data.get("category", existing_data.get("category"))

    if not category:
        return jsonify({"error": "category missing"}), 400


    # Convert JSON string fields to Python objects
    parse_json_fields(data, [
        "diseases",
        "bite_time",
        "breeding_sites",
        "subspecies",
        "public_actions",
        "control_methods",
        "crops_affected",
        "active_period",
        "habitat",
        "damage_symptoms"
    ])


    # ============================
    # IMAGE HANDLING (0–N images)
    # ============================

    images = existing_data.get("images", [])

    files = request.files.getlist("images")

    for file in files:

        if file and file.filename != "":
            try:

                image_url = upload_category_image_to_supabase(
                    file,
                    category,
                    name
                )

            except Exception as e:
                return jsonify({"error": f"Image upload failed: {str(e)}"}), 500


    update_data = {k: v for k, v in data.items() if k != "name"}

    update_data["updatedAt"] = firestore.SERVER_TIMESTAMP


    try:

        doc_ref.set(update_data, merge=True)

        print(f"[CATEGORY UPDATED] {doc_id}")

        return jsonify({
            "status": "UPDATED",
            "documentId": doc_id
        }), 200

    except Exception as e:

        return jsonify({"error": str(e)}), 500

def upload_category_image_to_supabase(file, category, species):

    bucket = supabase.storage.from_("categories")

    species_id = species.strip().lower().replace(" ", "_")

    # Extract original extension
    ext = file.filename.rsplit(".", 1)[-1].lower() if "." in file.filename else "jpg"

    filename = f"{species_id}_{uuid.uuid4().hex}.{ext}"

    storage_path = f"{category}/{species_id}/{filename}"

    data = file.read()

    res = bucket.upload(
        storage_path,
        data,
        file_options={"content-type": file.content_type}
    )

    if isinstance(res, dict) and res.get("error"):
        raise Exception(res["error"])

    return bucket.get_public_url(storage_path)

# ===============================
# AUDIO STREAMING
# ===============================

@app.route('/audio', methods=['POST'])
def update_audio():
    data = request.get_json(silent=True)
    if not data:
<<<<<<< HEAD:backend_database/serverDeployment.py
        return jsonify({"error": "No JSON"}), 400
=======
        return jsonify({"error": "Invalid JSON"}), 400
>>>>>>> origin/main:backend_server/serverDeployment.py

    device_id = data.get("deviceId", "").strip()
    if not device_id:
        return jsonify({"error": "deviceId missing"}), 400

<<<<<<< HEAD:backend_database/serverDeployment.py
    audio_data = {
        "isRecording": data.get("isRecording", False),
        "recentRecordings": data.get("recentRecordings", [])
    }

    fs.reference(f"devices/{device_id}/audio").set(audio_data)
=======
    if not device_id or not user_id:
        return jsonify({"error": "deviceId and userId required"}), 400

    # Ownership validation
    ok, error = validate_device_owner(device_id, user_id)
    if not ok:
        return jsonify(error[0]), error[1]
    
    # Check CONNECTED (Firestore)
    device_doc = fs.collection("devices").document(device_id).get()
    if not device_doc.exists or device_doc.to_dict().get("status") != "CONNECTED":
        return jsonify({
            "error": "Device must be CONNECTED to start audio"
        }), 409

    # Check ONLINE (RTDB)
    status = rtdb.reference(f"devices/{device_id}/status").get()
    if not status or not status.get("isOnline"):
        return jsonify({
            "error": "Device must be ONLINE to start audio"
        }), 409
    

    # Queue START_AUDIO
    device_commands[device_id] = {
        "command": "START_AUDIO",
        "userId": user_id,
        "issuedAt": int(time.time())
    }

    # Mark recording ON
    rtdb.reference(f"devices/{device_id}/audio").update({
        "isRecording": True
    })

    print(f"[START_AUDIO QUEUED] {device_id}")
>>>>>>> origin/main:backend_server/serverDeployment.py

    return jsonify({
        "message": "audio metadata stored",
        "audio": audio_data
    }), 200

@app.route('/audio/<device_id>', methods=['GET'])
def get_audio(device_id):
    ref = fs.reference(f"devices/{device_id.strip()}/audio")
    data = ref.get()

    if not data:
<<<<<<< HEAD:backend_database/serverDeployment.py
        return jsonify({"error": "No audio data"}), 404
=======
        return jsonify({"error": "Invalid JSON"}), 400

    device_id = data.get("deviceId", "").strip()
    user_id   = data.get("userId", "").strip()

    if not device_id or not user_id:
        return jsonify({"error": "deviceId and userId required"}), 400

    # Ownership validation
    ok, error = validate_device_owner(device_id, user_id)
    if not ok:
        return jsonify(error[0]), error[1]
    
    # Check CONNECTED (Firestore)
    device_doc = fs.collection("devices").document(device_id).get()
    if not device_doc.exists or device_doc.to_dict().get("status") != "CONNECTED":
        return jsonify({
            "error": "Device must be CONNECTED to stop audio"
        }), 409

    # Check ONLINE (RTDB)
    status = rtdb.reference(f"devices/{device_id}/status").get()
    if not status or not status.get("isOnline"):
        return jsonify({
            "error": "Device must be ONLINE to stop audio"
        }), 409

    # Queue STOP_AUDIO
    device_commands[device_id] = {
        "command": "STOP_AUDIO",
        "userId": user_id,
        "issuedAt": int(time.time())
    }

    # Update recording state
    rtdb.reference(f"devices/{device_id}/audio").update({
        "isRecording": False
    })

    # FINAL FLUSH
    if (
        device_id in audio_buffers
        and device_id in audio_locks
        and audio_buffers[device_id]
    ):
        with audio_locks[device_id]:
            raw_audio = bytes(audio_buffers[device_id])
            audio_buffers[device_id].clear()

        flush_audio_chunk(device_id, raw_audio)

    print(f"[STOP_AUDIO QUEUED] {device_id}")

    return jsonify({
        "status": "STOP_AUDIO_QUEUED",
        "deviceId": device_id
    }), 200

# ===============================
# HUGGING PHASE
# ===============================
# ===============================
# HUGGINGFACE INFERENCE
# ===============================
def send_audio_to_model(filepath, device_id):

    try:
        result = hf_client.predict(
            audio_filepath=handle_file(filepath),
            api_name="/analyze_wingbeat"
        )

        message = result[0]
        prediction = result[1]

        species = prediction["label"]
        confidence = prediction["confidences"][0]["confidence"]

        print(f"[AI RESULT] {species} | Confidence: {confidence}")

        # Save result to Firebase
        detection_data = {
            "species": species,
            "confidence": confidence,
            "message": message,
            "timestamp": int(time.time())
        }

        rtdb.reference(f"devices/{device_id}/detections").push(detection_data)

        print(f"[DETECTION STORED] {device_id}")

    except Exception as e:
        print(f"[AI ERROR] {e}")

# ===============================
# AUDIO WEBSOCKET
# ===============================
def upload_audio_to_supabase(filepath, filename):
    with open(filepath, "rb") as f:
        audio_bytes = f.read()

    bucket = supabase.storage.from_("audio-recordings")

    response = bucket.upload(
        filename,
        audio_bytes,
        file_options={"content-type": "audio/wav"}
    )

    if hasattr(response, "error") and response.error:
        raise Exception(response.error)

    return bucket.get_public_url(filename)

def store_audio_metadata(device_id, audio_url):
    ref = rtdb.reference(f"devices/{device_id}/audio")

    snapshot = ref.get() or {}
    recordings = snapshot.get("recentRecordings", [])

    if isinstance(recordings, dict):
        recordings = list(recordings.values())

    ts = int(time.time())
    audio_id = f"AUD_{device_id}_{ts}"

    recordings.append({
        "audioId": audio_id,
        "audioUrl": audio_url,
        "recordedAt": ts,
        "status": "COMPLETED"
    })

    ref.update({
        "recentRecordings": recordings
    })

# ===============================
# PROCESS 5-SECOND AUDIO CHUNK
# ===============================
# ===============================
# PROCESS 5-SECOND AUDIO CHUNK
# ===============================
def flush_audio_chunk(device_id, raw_audio):

    timestamp = int(time.time())
    filename = f"{device_id}_{timestamp}.wav"
    filepath = os.path.join(AUDIO_DIR, filename)

    # 1️⃣ Save raw PCM as WAV
    with wave.open(filepath, "wb") as wf:
        wf.setnchannels(CHANNELS)
        wf.setsampwidth(SAMPLE_WIDTH)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(raw_audio)

    public_url = upload_audio_to_supabase(filepath, filename)
    store_audio_metadata(device_id, public_url)

    # 3️⃣ Send audio to HuggingFace AI
    try:
        send_audio_to_model(filepath, device_id)

    except Exception as e:
        print(f"[AI ERROR] {e}")

@sock.route("/startAudioStream")
def audio_stream(ws):
    device_id = None

    try:
        # FIRST MESSAGE MUST BE deviceId
        device_id = ws.receive()
        if not device_id:
            ws.close()
            return

        print(f"[AUDIO CONNECT] {device_id}")

        audio_buffers.setdefault(device_id, bytearray())
        audio_locks.setdefault(device_id, Lock())

        while True:
            data = ws.receive()
            if data is None:
                break

            if isinstance(data, bytes):
                with audio_locks[device_id]:
                    audio_buffers[device_id].extend(data)

                    # EXACT 5s slicing
                    while len(audio_buffers[device_id]) >= CHUNK_BYTES:
                        chunk = audio_buffers[device_id][:CHUNK_BYTES]
                        audio_buffers[device_id] = audio_buffers[device_id][CHUNK_BYTES:]

                        flush_audio_chunk(device_id, bytes(chunk))

    except Exception as e:
        print(f"[AUDIO ERROR] {e}")

    finally:
        print(f"[AUDIO DISCONNECT] {device_id}")

        # Save leftover (<5s)
        if device_id in audio_buffers and audio_buffers[device_id]:
            flush_audio_chunk(device_id, bytes(audio_buffers[device_id]))
            audio_buffers[device_id].clear()

>>>>>>> origin/main:backend_server/serverDeployment.py

    return jsonify(data), 200


# ===============================
# OFFLINE CHECKER THREAD
# ===============================

<<<<<<< HEAD:backend_database/serverDeployment.py
ALIVE_TIMEOUT = 5 * 60
=======
def maintenance_worker():
    token_check_counter = 0  # counts minutes
    OFFLINE_THRESHOLD = 120  # seconds (2 minutes)
>>>>>>> origin/main:backend_server/serverDeployment.py

def offline_checker():
    while True:
        now = int(time.time())
        for device_id, info in list(devices.items()):
            if info.get("user_connected"):
                last_seen = info.get("last_seen", 0)
                if now - last_seen > ALIVE_TIMEOUT:
                    if info.get("status") != "OFFLINE":
                        info["status"] = "OFFLINE"
                        print(f"[OFFLINE] {device_id}")
        time.sleep(60)



# ===============================
# ENTRY POINT
# ===============================

<<<<<<< HEAD:backend_database/serverDeployment.py
if __name__ == '__main__':
    threading.Thread(target=offline_checker, daemon=True).start()
    app.run(host="0.0.0.0", port=PORT)
=======
if __name__ == "__main__":
    port = int(os.environ.get("PORT", 10000))
    app.run(host='0.0.0.0', port=port)
>>>>>>> origin/main:backend_server/serverDeployment.py
