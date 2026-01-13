import time
import os
import wave
import threading
from datetime import datetime
from flask import Flask, request, jsonify

app = Flask(__name__)

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

audio_buffer = bytearray()
recording = False

devices = {}           # device status & weather
device_commands = {}   # pending commands

# ===============================
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

    print(f"[ALIVE] {device_id} ONLINE")
    return jsonify({"message": "ALIVE received"}), 200


@app.route('/devices', methods=['GET'])
def list_devices():
    return jsonify(devices), 200


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

    devices.setdefault(device_id, {})
    devices[device_id]["weather"] = {
        "temperature": data.get("temperature"),
        "humidity": data.get("humidity"),
        "updated_at": int(time.time())
    }

    print(f"[WEATHER] {device_id} → {devices[device_id]['weather']}")
    return jsonify({"message": "weather stored"}), 200


@app.route('/weather/<device_id>', methods=['GET'])
def get_weather(device_id):
    device = devices.get(device_id.strip())
    if not device or "weather" not in device:
        return jsonify({"error": "No data"}), 404

    return jsonify(device["weather"]), 200


# ===============================
# CONNECTION CONTROL
# ===============================

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
# AUDIO STREAMING
# ===============================

@app.route("/start", methods=["POST"])
def start_recording():
    global recording, audio_buffer

    audio_buffer = bytearray()
    recording = True

    print("🔴 Recording started")
    return jsonify({"status": "recording started"}), 200


@app.route("/audio", methods=["POST"])
def receive_audio():
    global audio_buffer, recording

    if not recording:
        return "", 204

    audio_buffer.extend(request.data)
    return "", 204


@app.route("/stop", methods=["POST"])
def stop_recording():
    global recording, audio_buffer

    recording = False

    if len(audio_buffer) == 0:
        return jsonify({"error": "No audio to save"}), 400

    filename = datetime.now().strftime("audio_%Y%m%d_%H%M%S.wav")
    filepath = os.path.join(AUDIO_DIR, filename)

    with wave.open(filepath, "wb") as wf:
        wf.setnchannels(CHANNELS)
        wf.setsampwidth(SAMPLE_WIDTH)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(audio_buffer)

    audio_buffer = bytearray()
    print(f"💾 Saved {filepath}")

    return jsonify({
        "status": "recording stopped",
        "saved_as": filename
    }), 200


# ===============================
# OFFLINE CHECKER THREAD
# ===============================

ALIVE_TIMEOUT = 5 * 60

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

if __name__ == '__main__':
    threading.Thread(target=offline_checker, daemon=True).start()
    app.run(host="0.0.0.0", port=PORT)
