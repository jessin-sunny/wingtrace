from torchvision.datasets import ImageFolder
from torch.utils.data import DataLoader
from config import *
from utils.transforms import train_transform, val_transform

import os


def get_dataloaders():

    train_dataset = ImageFolder(
        os.path.join(DATASET_PATH, "train"),
        transform=train_transform
    )

    val_dataset = ImageFolder(
        os.path.join(DATASET_PATH, "val"),
        transform=val_transform
    )

    test_dataset = ImageFolder(
        os.path.join(DATASET_PATH, "test"),
        transform=val_transform
    )

    train_loader = DataLoader(
        train_dataset,
        batch_size=BATCH_SIZE,
        shuffle=True,
        num_workers=4
    )

    val_loader = DataLoader(
        val_dataset,
        batch_size=BATCH_SIZE,
        shuffle=False,
        num_workers=4
    )

    test_loader = DataLoader(
        test_dataset,
        batch_size=BATCH_SIZE,
        shuffle=False,
        num_workers=4
    )
    # print("Class mapping:", train_dataset.class_to_idx)
    return train_loader, val_loader, test_loader