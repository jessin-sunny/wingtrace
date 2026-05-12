import os
import cv2
import torch
from torch.utils.data import Dataset, DataLoader

import albumentations as A
from albumentations.pytorch import ToTensorV2


# -----------------------------
# Augmentations
# -----------------------------

train_transform = A.Compose([
    A.SmallestMaxSize(max_size=256),
    A.RandomCrop(height=224, width=224),
    A.HorizontalFlip(p=0.5),
    A.Rotate(limit=15, p=0.5),
    A.RandomBrightnessContrast(p=0.3),
    A.GaussianBlur(p=0.1),
    A.Normalize(
        mean=(0.485,0.456,0.406),
        std=(0.229,0.224,0.225)
    ),
    ToTensorV2()
])


val_transform = A.Compose([
    A.SmallestMaxSize(max_size=256),
    A.CenterCrop(height=224, width=224),
    A.Normalize(
        mean=(0.485,0.456,0.406),
        std=(0.229,0.224,0.225)
    ),
    ToTensorV2()
])


# -----------------------------
# Dataset Class
# -----------------------------

class PestDataset(Dataset):

    def __init__(self, root_dir, transform=None):

        self.root_dir = root_dir
        self.transform = transform

        self.image_paths = []
        self.labels = []

        self.classes = sorted(os.listdir(root_dir))
        self.class_to_idx = {cls:i for i,cls in enumerate(self.classes)}

        for cls in self.classes:

            cls_path = os.path.join(root_dir, cls)

            if not os.path.isdir(cls_path):
                continue

            for img in os.listdir(cls_path):

                img_path = os.path.join(cls_path, img)

                if img.lower().endswith((".jpg",".jpeg",".png",".bmp")):
                    self.image_paths.append(img_path)
                    self.labels.append(self.class_to_idx[cls])


    def __len__(self):
        return len(self.image_paths)


    def __getitem__(self, idx):

        img_path = self.image_paths[idx]

        image = cv2.imread(img_path)

        if image is None:
            raise ValueError(f"Failed to read image {img_path}")

        image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

        if self.transform:
            image = self.transform(image=image)["image"]

        label = self.labels[idx]

        return image, label


# -----------------------------
# DataLoader Function
# -----------------------------

def get_dataloaders(dataset_root, batch_size=32):

    train_dataset = PestDataset(
        os.path.join(dataset_root,"train"),
        transform=train_transform
    )

    val_dataset = PestDataset(
        os.path.join(dataset_root,"val"),
        transform=val_transform
    )

    test_dataset = PestDataset(
        os.path.join(dataset_root,"test"),
        transform=val_transform
    )


    train_loader = DataLoader(
        train_dataset,
        batch_size=batch_size,
        shuffle=True,
        num_workers=4,
        pin_memory=True
    )


    val_loader = DataLoader(
        val_dataset,
        batch_size=batch_size,
        shuffle=False,
        num_workers=4,
        pin_memory=True
    )


    test_loader = DataLoader(
        test_dataset,
        batch_size=batch_size,
        shuffle=False,
        num_workers=4,
        pin_memory=True
    )


    return train_loader, val_loader, test_loader