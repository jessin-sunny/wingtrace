# dataset_loader/mosquito_dataset.py

import os
from torch.utils.data import Dataset

from preprocessing.audio_utils import load_audio, apply_augmentation
from preprocessing.spectrogram import process_audio

from configs.config import CLASSES


class MosquitoDataset(Dataset):

    def __init__(self, data_dir, train=False):

        self.data_dir = data_dir
        self.train = train

        self.file_paths = []
        self.labels = []

        self._load_dataset()

    # -------------------------------------------------
    # Scan dataset folders
    # -------------------------------------------------

    def _load_dataset(self):

        for label_index, class_name in enumerate(CLASSES):

            class_dir = os.path.join(self.data_dir, class_name)

            for file in os.listdir(class_dir):

                if file.endswith(".wav"):

                    path = os.path.join(class_dir, file)

                    self.file_paths.append(path)

                    self.labels.append(label_index)

    # -------------------------------------------------

    def __len__(self):

        return len(self.file_paths)

    # -------------------------------------------------

    def __getitem__(self, index):

        file_path = self.file_paths[index]

        label = self.labels[index]

        # load audio
        signal = load_audio(file_path)

        # apply augmentation only during training
        if self.train:

            signal = apply_augmentation(signal)

        # generate spectrogram tensor
        spectrogram = process_audio(signal)

        return spectrogram, label