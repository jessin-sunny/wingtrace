from flask import Flask, request, jsonify
import time
import firebase_admin
from firebase_admin import credentials, db

app = Flask(__name__)

# ---------------------------
# FIREBASE INIT
# ---------------------------
cred = credentials.Certificate("serviceAccountKey.json")  # your key
firebase_admin.initialize_app(cred, {
    "databaseURL": "https://<your-project-id>.firebaseio.com/"
})

# ---------------------------
# ALIVE STATUS (5 mins)
# ---------------------------
@app.route('/alive', methods=['POST'])
def alive():
    data = request.get_json()
    if not data:
        return jsonify({"error": "No JSON received"}), 400

    device_id = data.get("deviceId")
    if not device_id:
        return jsonify({"error": "deviceId missing"}), 400

    now = int(time.time())

    device_ref = db.reference(f"devices/{device_id}")

    device_ref.update({
        "status": "ONLINE",
        "last_seen": now
    })

    print(f"[ALIVE] {device_id} @ {now}")
    return jsonify({"message": "ALIVE received"}), 200


# ---------------------------
# WEATHER DATA (1 min)
# ---------------------------
@app.route('/weather', methods=['POST'])
def weather():
    """
    Device sends:
    {
        "deviceId": "WingTraceV1_001",
        "temperature": 28.4,
        "humidity": 63
    }
    """
    data = request.get_json()
    if not data:
        return jsonify({"error": "No JSON received"}), 400

    device_id = data.get("deviceId")
    temperature = data.get("temperature")
    humidity = data.get("humidity")

    if not device_id:
        return jsonify({"error": "deviceId missing"}), 400

    now = int(time.time())

    device_ref = db.reference(f"devices/{device_id}/weather")
    device_ref.set({
        "temperature": temperature,
        "humidity": humidity,
        "updated_at": now
    })

    print(f"[WEATHER] {device_id} T={temperature} H={humidity}")
    return jsonify({"message": "Weather updated"}), 200


# ---------------------------
# DEVICE CLAIM / MAPPING
# ---------------------------
@app.route('/claim', methods=['POST'])
def claim_device():
    """
    App sends:
    {
        "deviceId": "WingTraceV1_001",
        "userId": "user_123"
    }
    """
    data = request.get_json()
    device_id = data.get("deviceId")
    user_id = data.get("userId")

    if not device_id or not user_id:
        return jsonify({"error": "Missing fields"}), 400

    device_ref = db.reference(f"devices/{device_id}")
    device_ref.update({
        "owner": user_id,
        "claimed": True
    })

    user_ref = db.reference(f"users/{user_id}/devices")
    user_ref.push(device_id)

    return jsonify({"message": "Device claimed"}), 200


# ---------------------------
# AUDIO METADATA (NO FILE YET)
# ---------------------------
@app.route('/audio_meta', methods=['POST'])
def audio_meta():
    """
    Device sends:
    {
        "deviceId": "WingTraceV1_001",
        "duration": 10,
        "sample_rate": 16000,
        "format": "PCM"
    }
    """
    data = request.get_json()
    device_id = data.get("deviceId")

    now = int(time.time())

    audio_ref = db.reference(f"audio_records/{device_id}/{now}")
    audio_ref.set({
        "duration": data.get("duration"),
        "sample_rate": data.get("sample_rate"),
        "format": data.get("format"),
        "storage_url": "PENDING"
    })

    device_audio_state = db.reference(f"devices/{device_id}/audio")
    device_audio_state.update({
        "state": "UPLOADING",
        "last_audio_time": now
    })

    return jsonify({"message": "Audio metadata stored"}), 200


# ---------------------------
# RUN SERVER
# ---------------------------
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
