import serial, wave

ser = serial.Serial("COM3", 921600, timeout=1)

frames = []
seconds = 10
sample_rate = 16000
bytes_needed = seconds * sample_rate * 2

while sum(len(f) for f in frames) < bytes_needed:
    frames.append(ser.read(4096))

ser.close()

pcm = b"".join(frames)

with wave.open("recording.wav", "wb") as wf:
    wf.setnchannels(1)
    wf.setsampwidth(2)
    wf.setframerate(sample_rate)
    wf.writeframes(pcm)
