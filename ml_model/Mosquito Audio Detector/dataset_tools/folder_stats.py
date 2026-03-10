import os
import librosa

folder = r"C:\My\RIT\S8\Project\WingTrace\ml_model\Mosquito Audio Detector\dataset\val\noise"

total_seconds = 0
file_count = 0

for file in os.listdir(folder):
    if file.endswith(".wav"):
        path = os.path.join(folder, file)

        y, sr = librosa.load(path, sr=None)
        duration = len(y) / sr

        total_seconds += duration
        file_count += 1

print("Total files:", file_count)

print("Total duration (seconds):", total_seconds)
print("Total duration (minutes):", total_seconds / 60)
print("Total duration (hours):", total_seconds / 3600)