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
from flask_sock import Sock
from threading import Lock
from supabase import create_client

app = Flask(__name__)
sock = Sock(app)

# firebase setup
firebase_key = json.loads(os.environ["FIREBASE_KEY"])

cred = credentials.Certificate(firebase_key)

firebase_admin.initialize_app(cred, {
    "databaseURL": "https://wingtrace-ead16-default-rtdb.firebaseio.com/"
})

rtdb_root = rtdb.reference()
fs = firestore.client()   # Firestore client

# Supabase
SUPABASE_URL = os.environ["SUPABASE_URL"]
SUPABASE_KEY = os.environ["SUPABASE_SERVICE_ROLE_KEY"]

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)


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

# ===============================
# AUDIO STATE (IN-MEMORY)
# ===============================

audio_buffers = {}     # deviceId -> bytearray
audio_locks = {}       # deviceId -> Lock
last_flush_time = {}   # deviceId -> timestamp

CHUNK_SECONDS = 5
SAMPLE_RATE = 16000
CHANNELS = 1
SAMPLE_WIDTH = 2  # int16

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
        "isReset": False,
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

    # Validate setup token
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

    # Validate device
    device_ref = fs.collection("devices").document(device_id)
    device_doc = device_ref.get()

    if not device_doc.exists:
        return jsonify({"error": "Unknown device"}), 404

    if device_doc.to_dict().get("ownerId"):
        return jsonify({"error": "Device already owned"}), 403

    # Assign ownership
    device_ref.set({
        "ownerId": owner_id,
        "status": "DISCONNECTED"
    }, merge=True)

    # Update user
    fs.collection("users").document(owner_id).set({
        "devices": firestore.ArrayUnion([device_id])
    }, merge=True)

    # Mark token as USED
    token_ref.update({
        "status": "USED",
        "deviceId": device_id
    })

    print(f"[ONBOARD] {device_id} → {owner_id}")

    device_commands.pop(device_id, None)  # clear stale commands

    rtdb.reference(f"devices/{device_id}/status").update({
        "isOnline": True,
        "isReset": False
    })

    return jsonify({
        "status": "SUCCESS",
        "deviceId": device_id
    }), 200

# vaild ownership checking
def validate_device_owner(device_id: str, user_id: str):
    """
    Returns (True, None) if valid
    Returns (False, (json, status_code)) if invalid
    """

    # Check user exists
    user_ref = fs.collection("users").document(user_id)
    user_doc = user_ref.get()
    if not user_doc.exists:
        return False, ({"error": "User not found"}, 404)

    # Check device exists
    device_ref = fs.collection("devices").document(device_id)
    device_doc = device_ref.get()
    if not device_doc.exists:
        return False, ({"error": "Device not found"}, 404)

    device_data = device_doc.to_dict()

    # Check ownership
    owner_id = device_data.get("ownerId")
    if owner_id != user_id:
        return False, ({"error": "User does not own this device"}, 403)

    return True, None

@app.route("/connect", methods=["POST"])
def connect_device():
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"error": "Invalid JSON"}), 400
    
    device_id = data.get("deviceId", "").strip()
    user_id   = data.get("userId", "").strip()

    if not device_id or not user_id:
        return jsonify({"error": "deviceId and userId required"}), 400

    # Ownership validation
    ok, error = validate_device_owner(device_id, user_id)
    if not ok:
        return jsonify(error[0]), error[1]

    # MUST be online
    status = rtdb.reference(f"devices/{device_id}/status").get()
    if not status or not status.get("isOnline"):
        return jsonify({
            "error": "Device must be ONLINE to connect"
        }), 409

    # Mark connected (user intent)
    fs.collection("devices").document(device_id).update({
        "status": "CONNECTED"
    })

    print(f"[CONNECT] {device_id}")

    return jsonify({
        "status": "CONNECTED",
        "deviceId": device_id
    }), 200

@app.route('/disconnect', methods=['POST'])
def disconnect():
    data = request.get_json(silent=True)
    device_id = data.get("deviceId", "").strip() if data else ""
    user_id   = data.get("userId", "").strip() if data else ""

    if not device_id or not user_id:
        return jsonify({"error": "deviceId and userId required"}), 400

    # Validate ownership
    ok, error = validate_device_owner(device_id, user_id)
    if not ok:
        return jsonify(error[0]), error[1]

    # CHECK DEVICE ONLINE STATUS
    status = rtdb.reference(f"devices/{device_id}/status").get()

    if not status or not status.get("isOnline"):
        return jsonify({
            "error": "Device must be ONLINE to disconnect"
        }), 409

    fs.collection("devices").document(device_id).update({
    "status": "DISCONNECTED"
    })

    # In-memory cleanup
    devices.pop(device_id, None)
    device_commands.pop(device_id, None)

    print(f"[DISCONNECT] {device_id} by {user_id}")

    return jsonify({
        "status": "SUCCESS",
        "deviceId": device_id
    }), 200

# ===============================
# COMMAND CHANNEL
# ===============================
# Fcatory Reset device
@app.route("/reset", methods=["POST"])
def reset_device():
    data = request.get_json(silent=True)
    device_id = data.get("deviceId", "").strip()
    user_id   = data.get("userId", "").strip()

    if not device_id or not user_id:
        return jsonify({"error": "deviceId and userId required"}), 400

    # Ownership validation
    ok, error = validate_device_owner(device_id, user_id)
    if not ok:
        return jsonify(error[0]), error[1]

    # Device must be online
    status = rtdb.reference(f"devices/{device_id}/status").get()
    if not status or not status.get("isOnline"):
        return jsonify({"error": "Device must be ONLINE"}), 409

    # Queue RESET (one-shot)
    device_commands[device_id] = {
        "command": "RESET",
        "userId": user_id,
        "issuedAt": int(time.time())
    }

    print(f"[RESET QUEUED] {device_id}")

    return jsonify({
        "status": "RESET_QUEUED",
        "deviceId": device_id
    }), 200

@app.route("/command", methods=["GET"])
def get_command():
    device_id = request.args.get("deviceId", "").strip()

    device_doc = fs.collection("devices").document(device_id).get()
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
            "isReset": True
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
# AUDIO CONTROLS
# ===============================
@app.route("/startAudio", methods=["POST"])
def start_audio():
    data = request.get_json(silent=True)
    device_id = data.get("deviceId", "").strip()
    user_id   = data.get("userId", "").strip()

    if not device_id or not user_id:
        return jsonify({"error": "deviceId and userId required"}), 400

    # Ownership validation
    ok, error = validate_device_owner(device_id, user_id)
    if not ok:
        return jsonify(error[0]), error[1]

    # Queue START_AUDIO
    device_commands[device_id] = {
        "command": "START_AUDIO",
        "userId": user_id,
        "issuedAt": int(time.time())
    }

    print(f"[START_AUDIO QUEUED] {device_id}")

    return jsonify({
        "status": "START_AUDIO_QUEUED",
        "deviceId": device_id
    }), 200

@app.route("/stopAudio", methods=["POST"])
def stop_audio():
    data = request.get_json(silent=True)
    device_id = data.get("deviceId", "").strip()
    user_id   = data.get("userId", "").strip()

    if not device_id or not user_id:
        return jsonify({"error": "deviceId and userId required"}), 400

    ok, error = validate_device_owner(device_id, user_id)
    if not ok:
        return jsonify(error[0]), error[1]

    device_commands[device_id] = {
        "command": "STOP_AUDIO",
        "userId": user_id,
        "issuedAt": int(time.time())
    }

    print(f"[STOP_AUDIO QUEUED] {device_id}")

    return jsonify({
        "status": "STOP_AUDIO_QUEUED",
        "deviceId": device_id
    }), 200

# ===============================
# AUDIO WEBSOCKET
# ===============================
def upload_to_supabase(filepath, filename):
    with open(filepath, "rb") as f:
        data = f.read()

    path = f"{filename}"

    res = supabase.storage.from_("audio-recordings").upload(
        path,
        data,
        {
            "content-type": "audio/wav"
        }
    )

    if res.get("error"):
        raise Exception(res["error"]["message"])

    public_url = supabase.storage.from_("audio-recordings").get_public_url(path)

    return public_url


def store_audio_metadata(device_id, url):
    ref = rtdb.reference(f"devices/{device_id}/audio")
    entry = {
        "url": url,
        "timestamp": int(time.time()),
        "duration": CHUNK_SECONDS
    }
    existing = ref.get() or []
    existing.append(entry)
    ref.set(existing)

def flush_audio(device_id, force=False):
    with audio_locks[device_id]:
        if not audio_buffers[device_id]:
            return

        raw_audio = bytes(audio_buffers[device_id])
        audio_buffers[device_id].clear()
        last_flush_time[device_id] = time.time()

    filename = f"{device_id}_{int(time.time())}.wav"
    filepath = os.path.join(AUDIO_DIR, filename)

    # Write WAV
    with wave.open(filepath, "wb") as wf:
        wf.setnchannels(CHANNELS)
        wf.setsampwidth(SAMPLE_WIDTH)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(raw_audio)

    # Upload & store metadata
    public_url = upload_to_supabase(filepath, filename)
    store_audio_metadata(device_id, public_url)

    print(f"[AUDIO SAVED] {filename}")

def maybe_flush_audio(device_id):
    now = time.time()
    if now - last_flush_time[device_id] >= CHUNK_SECONDS:
        flush_audio(device_id)

@sock.route('/startAudioStream')
def start_audio(ws):
    device_id = None

    try:
        # FIRST MESSAGE: deviceId (text)
        device_id = ws.receive()
        if not device_id:
            ws.close()
            return

        print(f"[AUDIO CONNECT] {device_id}")

        # Init per-device buffers
        audio_buffers.setdefault(device_id, bytearray())
        audio_locks.setdefault(device_id, Lock())
        last_flush_time.setdefault(device_id, time.time())

        while True:
            data = ws.receive()
            if data is None:
                break  # client disconnected

            if isinstance(data, bytes):
                with audio_locks[device_id]:
                    audio_buffers[device_id].extend(data)

                maybe_flush_audio(device_id)

    except Exception as e:
        print(f"[AUDIO ERROR] {e}")

    finally:
        print(f"[AUDIO DISCONNECT] {device_id}")
        flush_audio(device_id, force=True)



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
