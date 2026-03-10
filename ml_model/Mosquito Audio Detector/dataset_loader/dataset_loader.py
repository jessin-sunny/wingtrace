import sys
import os

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")))

import librosa
import torch
from torch.utils.data import Dataset

from preprocessing.spectrogram import (
    generate_log_mel,
    spectrogram_to_tensor,
    SAMPLE_RATE,
    WINDOW_FRAMES
)


class MosquitoDetectorDataset(Dataset):

    def __init__(self, root_dir):

        self.samples = []

        class_map = {
            "mosquito": 1,
            "noise": 0
        }

        for label_name in ["mosquito", "noise"]:

            label = class_map[label_name]
            folder = os.path.join(root_dir, label_name)

            for file in os.listdir(folder):

                if not file.endswith(".wav"):
                    continue

                path = os.path.join(folder, file)

                signal, sr = librosa.load(
                    path,
                    sr=SAMPLE_RATE,
                    mono=True
                )

                if len(signal) == 0:
                    continue

                mel = generate_log_mel(signal)

                frames = mel.shape[1]

                if frames < WINDOW_FRAMES:
                    continue

                # take first 19 frames
                window = mel[:, :WINDOW_FRAMES]

                tensor = spectrogram_to_tensor(window)

                self.samples.append((tensor, label))


    def __len__(self):
        return len(self.samples)


    def __getitem__(self, idx):

        tensor, label = self.samples[idx]

        return tensor, torch.tensor(label, dtype=torch.long)