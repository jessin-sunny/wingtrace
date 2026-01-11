from flask import Flask, request, jsonify

app = Flask(__name__)

# In-memory storage for demo (later can add DB)
devices_status = {}

# alive status every 5mins from device
@app.route('/alive', methods=['POST'])
def alive():
    """
    Device sends:
    {
        "deviceId": "WingTrace_V1",
        "status": "ALIVE"
    }
    """
    data = request.get_json()
    if not data:
        return jsonify({"error": "No JSON received"}), 400
    
    device_id = data.get("deviceId", "UNKNOWN")
    status = data.get("status", "UNKNOWN")
    
    # Save / update device status
    devices_status[device_id] = status
    
    print(f"[ALIVE] Device {device_id} status: {status}")
    
    return jsonify({"message": "ALIVE received"}), 200



# weather data from device every 1min monitoring

# update weather data in firebase

# audio later

# Optional: list all devices
@app.route('/devices', methods=['GET'])
def list_devices():
    return jsonify(devices_status), 200

if __name__ == '__main__':
    # Run server on all interfaces, port 5000
    app.run(host='0.0.0.0', port=5000)
