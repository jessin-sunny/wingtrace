import os
import numpy as np
from torch.utils.data import Dataset

from preprocessing.audio_utils import load_audio
from preprocessing.spectrogram import process_audio
from configs.config import SAMPLE_RATE, CLASSES


class HumBugDataset(Dataset):

    def __init__(self, root_dir):

        self.samples = []

        window_size = int(0.625 * SAMPLE_RATE)

        for label, genus in enumerate(CLASSES):

            genus_path = os.path.join(root_dir, genus)

            for file in os.listdir(genus_path):

                if not file.endswith(".wav"):
                    continue

                file_path = os.path.join(genus_path, file)

                signal = load_audio(file_path)

                # pad short audio
                if len(signal) < window_size:
                    signal = np.pad(signal, (0, window_size - len(signal)))

                # sliding windows
                for start in range(0, len(signal) - window_size + 1, window_size):

                    window = signal[start:start + window_size]

                    self.samples.append((window, label))

    def __len__(self):
        return len(self.samples)

    def __getitem__(self, idx):

        window, label = self.samples[idx]

        x = process_audio(window)

        return x, label