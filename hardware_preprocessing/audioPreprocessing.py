import serial
import wave
import numpy as np

PORT = "COM3"
BAUD = 921600
SAMPLE_RATE = 16000
SECONDS = 10
CHUNK = 4096

ser = serial.Serial(PORT, BAUD, timeout=1)

frames = []
bytes_needed = SAMPLE_RATE * 2 * SECONDS

print("Recording...")

while sum(len(f) for f in frames) < bytes_needed:
    data = ser.read(CHUNK)
    if data:
        frames.append(data)

ser.close()

# Combine all bytes
pcm_bytes = b"".join(frames)

# ---- IMPORTANT: align to int16 ----
pcm_bytes = pcm_bytes[:len(pcm_bytes) // 2 * 2]

# ---- Convert to numpy array ----
pcm_array = np.frombuffer(pcm_bytes, dtype=np.int16)

# ---- Save WAV ----
with wave.open("recording.wav", "wb") as wf:
    wf.setnchannels(1)
    wf.setsampwidth(2)
    wf.setframerate(SAMPLE_RATE)
    wf.writeframes(pcm_bytes)

# ---- Save NPY ----
np.save("recording.npy", pcm_array)

# ---- Print values (SAFE & READABLE) ----
print("\nFirst 20 PCM values:")
print(pcm_array[:20])

print("\nStats:")
print("Shape:", pcm_array.shape)
print("Min:", pcm_array.min())
print("Max:", pcm_array.max())
print("Mean:", pcm_array.mean())

print("\nSaved recording.wav and recording.npy")
