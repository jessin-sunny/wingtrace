import os
import librosa
import numpy as np

DATASET_PATH = r"C:\My\RIT\S8\Project\Dataset\Audio\Mosquito_3000"

sampling_rates = []
lengths = []
examples = []

for root, dirs, files in os.walk(DATASET_PATH):
    a = 0
    for file in files:
        if file.lower().endswith(".wav"):
            path = os.path.join(root, file)

            y, sr = librosa.load(path, sr=None)
            duration = len(y) / sr

            sampling_rates.append(sr)
            lengths.append(duration)
            a += 1
            if a < 5:
                examples.append((path, sr, duration))

print("Average Sampling Rate:", np.mean(sampling_rates))
print("Average Audio Length:", np.mean(lengths))

print("\nExamples:")
for p, sr, d in examples:
    print(p, "|", sr, "Hz |", d, "seconds")