import os
import wave

folder = r"C:\My\RIT\S8\Project\Audio Recordings\Orginal"

for file in os.listdir(folder):
    if file.endswith(".wav"):

        path = os.path.join(folder, file)

        with wave.open(path, 'rb') as wf:
            channels = wf.getnchannels()
            sample_width = wf.getsampwidth()
            sample_rate = wf.getframerate()
            frames = wf.getnframes()

            duration = frames / sample_rate

            print(f"File: {file}")
            print(f"Channels: {channels}")
            print(f"Sample Width: {sample_width} bytes")
            print(f"Sample Rate: {sample_rate} Hz")
            print(f"Frames: {frames}")
            print(f"Duration: {duration:.3f} seconds")
            print("-" * 40)