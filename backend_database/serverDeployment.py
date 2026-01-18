import wave
import threading
from datetime import datetime, timedelta, timezone
from flask import Flask, request, jsonify
import firebase_admin
from firebase_admin import credentials, db as rtdb
import os, json, time
from firebase_admin import firestore
import uuid
from threading import Lock
from google.cloud.firestore_v1 import FieldFilter

app = Flask(__name__)

# firebase setup
firebase_key = json.loads(os.environ["FIREBASE_KEY"])

cred = credentials.Certificate(firebase_key)

firebase_admin.initialize_app(cred, {
    "databaseURL": "https://wingtrace-ead16-default-rtdb.firebaseio.com/"
})

rtdb_root = rtdb.reference()
fs = firestore.client()   # Firestore client

devices_lock = Lock()   # Thread Safety

# ===============================
# CONFIG (Railway safe)
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

# ===============================
# GLOBAL STATE (in-memory)
# ===============================

devices = {}           # device status
device_commands = {}   # pending commands

audio_buffer = bytearray()
recording = False


# ===============================
# DEVICE HEARTBEAT
# ===============================

# Network Strength Classification
def classify_network_strength(rssi):
    if rssi is None:
        return "UNKNOWN"
    if rssi >= -55:
        return "STRONG"
    elif rssi >= -70:
        return "MODERATE"
    else:
        return "WEAK"
# Alive message
@app.route('/alive', methods=['POST'])
def alive():
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"error": "No JSON received"}), 400

    device_id = data.get("deviceId", "").strip()
    if not device_id:
        return jsonify({"error": "deviceId missing"}), 400

    # Raw values from ESP32
    battery_level = data.get("batteryLevel", None)
    rssi = data.get("networkStrength", None)

    # Server-side decisions
    signal_quality = classify_network_strength(rssi)
    now = int(time.time())

    # In-memory device state
    devices.setdefault(device_id, {})
    devices[device_id].update({
        "isOnline": True,
        "lastSeen": now,
        "batteryLevel": battery_level,
        "networkStrength": signal_quality,
    })

    # Firebase update
    rtdb.reference(f"devices/{device_id}/status").update({
        "isOnline": True,
        "lastSeen": now,
        "batteryLevel": battery_level,
        "networkStrength": signal_quality
    })

    print(f"[ALIVE] {device_id} | RSSI={rssi} | SIGNAL={signal_quality} | Battery Level={battery_level}")
    return jsonify({"message": "ALIVE received"}), 200


@app.route('/devices', methods=['GET'])
def list_devices():
    return jsonify(devices), 200

# ===============================
# DEVICE STATUS
# ===============================

@app.route('/status', methods=['POST'])
def get_status():
    data = request.get_json(force=True)
    device_id = data.get("deviceId", "").strip()

    if not device_id:
        return jsonify({"error": "deviceId missing"}), 400

    ref = rtdb.reference(f"devices/{device_id}/status")
    status_data = ref.get()

    if not status_data:
        return jsonify({"error": "No status data"}), 404

    return jsonify(status_data), 200


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

    rtdb.reference(f"devices/{device_id}/weather").set(weather_data)

    print(f"[WEATHER] {device_id} → {weather_data}")

    return jsonify({"message": "weather stored in firebase"}), 200


@app.route('/weatherRetrieval', methods=['POST'])
def get_weather():
    data = request.get_json(force=True)
    device_id = data.get("deviceId", "").strip()

    if not device_id:
        return jsonify({"error": "deviceId missing"}), 400

    ref = rtdb.reference(f"devices/{device_id}/weather")
    weather_data = ref.get()

    if not weather_data:
        return jsonify({"error": "No weather data"}), 404

    return jsonify(weather_data), 200


# ===============================
# CONNECTION CONTROL
# ===============================

# App calls
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

# Device calls
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

@app.route("/reset", methods=["POST"])
def reset_device():
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
    cmd = device_commands.get(device_id, "NO_COMMAND")

    if cmd != "NO_COMMAND":
        device_commands[device_id] = "NO_COMMAND"
        print(f"[CMD SENT] {device_id} → {cmd}")

    return cmd, 200

# ===============================
# ADMIN CONTROL
# ===============================

# Admin check
def require_admin(req):
    admin_key = req.headers.get("X-ADMIN-KEY")
    return admin_key == os.getenv("ADMIN_SECRET_KEY")

# ADMIN: Manufacture a new device and add information to database
@app.route("/addDevice", methods=["POST"])
def add_device():
    if not require_admin(request):
        return jsonify({"error": "Unauthorized"}), 401

    data = request.get_json(silent=True)
    if not data:
        return jsonify({"error": "Invalid JSON"}), 400

    device_id   = data.get("deviceId")
    device_name = data.get("deviceName")
    firmware    = data.get("firmwareVersion")
    createdAt   = data.get("createdAt")

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



# ===============================
# AUDIO STREAMING
# ===============================

@app.route('/audio', methods=['POST'])
def update_audio():
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"error": "No JSON"}), 400

    device_id = data.get("deviceId", "").strip()
    if not device_id:
        return jsonify({"error": "deviceId missing"}), 400

    audio_data = {
        "isRecording": data.get("isRecording", False),
        "recentRecordings": data.get("recentRecordings", [])
    }

    fs.reference(f"devices/{device_id}/audio").set(audio_data)

    return jsonify({
        "message": "audio metadata stored",
        "audio": audio_data
    }), 200

@app.route('/audio/<device_id>', methods=['GET'])
def get_audio(device_id):
    ref = fs.reference(f"devices/{device_id.strip()}/audio")
    data = ref.get()

    if not data:
        return jsonify({"error": "No audio data"}), 404

    return jsonify(data), 200


# ===============================
# OFFLINE CHECKER THREAD
# CONTINUOSLY MONITORING
# ===============================

def maintenance_worker():
    token_check_counter = 0  # counts minutes
    OFFLINE_THRESHOLD = 360  # seconds (6 minutes)

    while True:
        now = int(time.time())

        # =====================================
        # DEVICE OFFLINE MONITOR (FIREBASE-BASED)
        # =====================================
        devices_snapshot = rtdb.reference("devices").get() or {}

        for device_id, device_data in devices_snapshot.items():
            status = device_data.get("status", {})
            last_seen = status.get("lastSeen")
            is_online = status.get("isOnline")

            if not last_seen or not is_online:
                continue

            if now - last_seen > OFFLINE_THRESHOLD:
                rtdb.reference(f"devices/{device_id}/status").update({
                    "isOnline": False
                })

                print(f"[DEVICE OFFLINE] {device_id}")

        # =====================================
        # TOKEN MAINTENANCE TIMING
        # =====================================
        token_check_counter += 1
        now_utc = datetime.now(timezone.utc)

        # -------------------------------------
        # EXPIRE SETUP TOKENS (every 5 minutes)
        # -------------------------------------
        if token_check_counter % 5 == 0:
            expired_count = 0

            waiting_tokens = (
                fs.collection("setupSessions")
                .where(filter=FieldFilter("status", "==", "WAITING"))
                .stream()
            )

            for doc in waiting_tokens:
                data = doc.to_dict()
                expires_at = data.get("expiresAt")

                if not expires_at:
                    continue

                if expires_at.tzinfo is None:
                    expires_at = expires_at.replace(tzinfo=timezone.utc)

                if expires_at < now_utc:
                    doc.reference.update({"status": "EXPIRED"})
                    expired_count += 1

            if expired_count:
                print(f"[TOKEN EXPIRED] {expired_count} marked")

        # -------------------------------------
        # DELETE EXPIRED TOKENS (every 10 minutes)
        # -------------------------------------
        if token_check_counter % 10 == 0:
            deleted_count = 0

            expired_tokens = (
                fs.collection("setupSessions")
                .where(filter=FieldFilter("status", "==", "EXPIRED"))
                .stream()
            )

            for doc in expired_tokens:
                doc.reference.delete()
                deleted_count += 1

            if deleted_count:
                print(f"[TOKEN DELETED] {deleted_count} removed")

        time.sleep(60)  # run once per minute

# Thread Run
monitor_thread = threading.Thread(
    target=maintenance_worker,
    daemon=True
)
monitor_thread.start()

# ===============================
# ENTRY POINT
# ===============================

if __name__ == '__main__':
    app.run(host="0.0.0.0", port=PORT)
