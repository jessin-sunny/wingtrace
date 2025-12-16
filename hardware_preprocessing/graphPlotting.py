import serial
import time
import matplotlib.pyplot as plt

# ================= SERIAL CONFIG =================
PORT = 'COM3'        # change if needed
BAUD = 115200
ser = serial.Serial(PORT, BAUD, timeout=1)

print("Type 'start' to record, 'stop' to stop recording")

recording = False
audio_buffer = []
time_buffer = []

start_time = 0

# ================= COMMAND LOOP =================
while True:
    cmd = input("> ").strip().lower()

    if cmd == "start":
        print("Recording started...")
        audio_buffer.clear()
        time_buffer.clear()
        start_time = time.time()
        recording = True

        while recording:
            if ser.in_waiting:
                line = ser.readline().decode().strip()
                try:
                    sample = int(line)
                    t = time.time() - start_time

                    audio_buffer.append(sample)
                    time_buffer.append(t)

                except ValueError:
                    pass

            # check for stop command without blocking
            if ser.in_waiting == 0:
                if input("Type 'stop' to end recording: ").strip().lower() == "stop":
                    recording = False
                    print("Recording stopped")

    elif cmd == "stop":
        print("Not recording")

    elif cmd == "exit":
        break

# ================= CLEANUP =================
ser.close()

# ================= PLOT AFTER RECORDING =================
if audio_buffer:
    plt.figure()
    plt.plot(time_buffer, audio_buffer)
    plt.xlabel("Time (s)")
    plt.ylabel("Amplitude (PCM)")
    plt.title("Recorded Audio Waveform")
    plt.grid(True)
    plt.show()
else:
    print("No audio recorded")
