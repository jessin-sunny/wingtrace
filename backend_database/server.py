import time
from flask import Flask, request, jsonify
import wave
import os
from datetime import datetime
app = Flask(__name__)

# alive status every 5mins from device
import time

AUDIO_DIR = "recordings"
os.makedirs(AUDIO_DIR, exist_ok=True)

# Audio config (must match ESP32)
SAMPLE_RATE = 16000
CHANNELS = 1
SAMPLE_WIDTH = 2  # 16-bit PCM

audio_buffer = bytearray()
recording = False

# In-memory storage for demo (later can add DB)
devices = {}
# Store pending commands for devices
device_commands = {}



@app.route('/alive', methods=['POST'])
def alive():
    data = request.get_json()
    if not data:
        return jsonify({"error": "No JSON received"}), 400

    device_id = data.get("deviceId", "").strip()
    if not device_id:
        return jsonify({"error": "deviceId missing"}), 400

    devices.setdefault(device_id, {})
    devices[device_id]["status"] = "ONLINE"
    devices[device_id]["last_seen"] = int(time.time())
    devices[device_id]["user_connected"] = True  # user still wants to be connected

    print(f"[ALIVE] {device_id} ONLINE at {devices[device_id]['last_seen']}")

    return jsonify({"message": "ALIVE received"}), 200

# weather data from device every 1min monitoring

# Optional: list all devices
@app.route('/devices', methods=['GET'])
def list_devices():
    return jsonify(devices), 200

@app.route('/weather', methods=['POST'])
def weather():
    print("---- WEATHER ENDPOINT HIT ----")
    print("Raw data:", request.data)

    data = request.get_json(silent=True)
    print("Parsed JSON:", data)

    if not data:
        return jsonify({"error": "No JSON"}), 400

    device_id = data.get("deviceId", "").strip()
    temp = data.get("temperature")
    hum = data.get("humidity")

    if not device_id:
        return jsonify({"error": "deviceId missing"}), 400

    devices.setdefault(device_id, {})  # ensure dict exists
    devices[device_id]["weather"] = {
        "temperature": temp,
        "humidity": hum,
        "updated_at": int(time.time())
    }

    print("[WEATHER STORED]", devices)

    return jsonify({"message": "weather stored"}), 200

@app.route('/weather/<device_id>', methods=['GET'])
def get_weather(device_id):
    device_id = device_id.strip()  # clean whitespace/newlines

    device = devices.get(device_id)
    
    # Check if device exists and has weather data
    if not device or not isinstance(device, dict) or "weather" not in device:
        return jsonify({"error": "No data"}), 404

    # Return the weather dictionary
    return jsonify(device["weather"]), 200

@app.route('/disconnect', methods=['POST'])
def disconnect():
    data = request.get_json()
    device_id = data.get("deviceId", "").strip()
    if not device_id or device_id not in devices:
        return jsonify({"error": "Invalid deviceId"}), 400

    devices[device_id]["status"] = "OFFLINE"
    devices[device_id]["user_connected"] = False
    print(f"[DISCONNECT] Device {device_id} manually disconnected")

    return jsonify({"message": "Device disconnected"}), 200

# reset device
@app.route("/reset", methods=["POST"])
def reset_device():
    data = request.get_json()
    device_id = data.get("deviceId", "").strip() if data else ""

    if not device_id:
        return jsonify({"error": "deviceId required"}), 400

    device_commands[device_id] = "RESET"
    print(f"🔁 RESET issued for {device_id}")

    return jsonify({"status": "RESET command queued"}), 200


# command
@app.route("/command", methods=["GET"])
def get_command():
    device_id = request.args.get("deviceId", "").strip()

    cmd = device_commands.get(device_id, "NO_COMMAND")

    if cmd != "NO_COMMAND":
        device_commands[device_id] = "NO_COMMAND"
        print(f"[CMD SENT] {device_id} → {cmd}")

    return cmd, 200



# audio flow
@app.route("/start", methods=["POST"])
def start_recording():
    global recording, audio_buffer

    audio_buffer = bytearray()
    recording = True

    device_commands["WT12012026"] = "START_AUDIO"
    print("🔴 Recording started")

    return jsonify({"status": "recording started"}), 200


@app.route("/audio", methods=["POST"])
def receive_audio():
    global audio_buffer, recording

    if not recording:
        return "", 204   # important

    audio_buffer.extend(request.data)
    return "", 204


@app.route("/stop", methods=["POST"])
def stop_recording():
    global recording, audio_buffer

    # 1️⃣ Stop accepting audio
    recording = False

    # 2️⃣ Tell ESP32 to stop streaming
    device_commands["WT12012026"] = "STOP_AUDIO"
    print("⏹ Stop issued")

    # 3️⃣ Validate audio
    if len(audio_buffer) == 0:
        return jsonify({"error": "No audio to save"}), 400

    # 4️⃣ Save WAV
    filename = datetime.now().strftime("audio_%Y%m%d_%H%M%S.wav")
    filepath = os.path.join(AUDIO_DIR, filename)

    with wave.open(filepath, "wb") as wf:
        wf.setnchannels(CHANNELS)
        wf.setsampwidth(SAMPLE_WIDTH)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(audio_buffer)

    print(f"💾 Saved: {filepath}")

    # 5️⃣ Clear buffer (important)
    audio_buffer = bytearray()

    return jsonify({
        "status": "recording stopped",
        "saved_as": filepath
    }), 200


import threading

ALIVE_TIMEOUT = 5 * 60  # 5 minutes in seconds

def offline_checker():
    while True:
        now = int(time.time())
        for device_id, info in devices.items():
            # Only check devices where user wants to stay connected
            if info.get("user_connected", False):
                last_seen = info.get("last_seen", 0)
                if now - last_seen > ALIVE_TIMEOUT:
                    if info.get("status") != "OFFLINE":
                        info["status"] = "OFFLINE"
                        print(f"[OFFLINE] Device {device_id} timed out")
        time.sleep(60)  # check every 1 min


if __name__ == '__main__':
    # Start offline checker thread
    threading.Thread(target=offline_checker, daemon=True).start()
    # Run server on all interfaces, port 5000
    app.run(host='0.0.0.0', port=5000)
