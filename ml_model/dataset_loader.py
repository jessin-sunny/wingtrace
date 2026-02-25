import os
import torch
import librosa
import numpy as np
from torch.utils.data import Dataset

class PestAudioDataset(Dataset):
    def __init__(self, root_dir, sr=22050, n_mels=128):
        self.root_dir = root_dir
        self.sr = sr
        self.n_mels = n_mels

        self.classes = sorted(os.listdir(root_dir))
        self.class_to_idx = {cls_name: i for i, cls_name in enumerate(self.classes)}

        self.file_list = []

        for cls in self.classes:
            cls_path = os.path.join(root_dir, cls)
            for file in os.listdir(cls_path):
                if file.endswith(".wav"):
                    self.file_list.append(
                        (os.path.join(cls_path, file), self.class_to_idx[cls])
                    )

    def __len__(self):
        return len(self.file_list)

    def __getitem__(self, idx):
        file_path, label = self.file_list[idx]

        # Load audio
        audio, sr = librosa.load(file_path, sr=self.sr, mono=True)

        # Create mel spectrogram
        mel = librosa.feature.melspectrogram(
            y=audio,
            sr=self.sr,
            n_mels=self.n_mels,
            hop_length=512
        )

        # Convert to log scale
        mel_db = librosa.power_to_db(mel, ref=np.max)

        # Normalize to 0-1
        mel_db = (mel_db - mel_db.min()) / (mel_db.max() - mel_db.min())

        # Convert to tensor
        mel_tensor = torch.tensor(mel_db, dtype=torch.float32)

        # Add channel dimension for CNN
        mel_tensor = mel_tensor.unsqueeze(0)
        mel_tensor = mel_tensor.repeat(3, 1, 1)   # Convert 1 channel → 3 channels

        return mel_tensor, label