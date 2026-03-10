import os
import librosa
import numpy as np

TEST_DIR = r"C:\My\RIT\S8\Project\Dataset\Audio\HumBug_Genus\train"

CLASSES = ["Aedes", "Anopheles", "Culex"]

for genus in CLASSES:

    genus_path = os.path.join(TEST_DIR, genus)

    lengths = []

    for file in os.listdir(genus_path):

        if not file.endswith(".wav"):
            continue

        path = os.path.join(genus_path, file)

        signal, sr = librosa.load(path, sr=8000)

        duration = len(signal) / sr

        lengths.append(duration)

    lengths = np.array(lengths)

    total_seconds = lengths.sum()

    print("\n==============================")
    print(f"{genus}")
    print("==============================")

    print("Files:", len(lengths))
    print("Min length:", round(lengths.min(), 3), "seconds")
    print("Max length:", round(lengths.max(), 3), "seconds")
    print("Mean length:", round(lengths.mean(), 3), "seconds")

    print("Total duration:", round(total_seconds, 2), "seconds")
    print("Total duration:", round(total_seconds/60, 2), "minutes")