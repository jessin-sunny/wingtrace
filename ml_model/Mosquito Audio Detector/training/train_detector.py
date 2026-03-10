import sys
import os

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import torch
import torch.nn as nn
from torch.utils.data import DataLoader

from dataset_loader.dataset_loader import MosquitoDetectorDataset
from models.resnet_detector import get_detector_resnet


# -------------------------------------------------
# Paths
# -------------------------------------------------

TRAIN_DIR = "ml_model/Mosquito Audio Detector/dataset/train"
VAL_DIR = "ml_model/Mosquito Audio Detector/dataset/val"

BATCH_SIZE = 32
EPOCHS = 5
LEARNING_RATE = 3e-4


def main():

    # -------------------------------------------------
    # Device
    # -------------------------------------------------

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print("Using device:", device)


    # -------------------------------------------------
    # Dataset
    # -------------------------------------------------

    train_dataset = MosquitoDetectorDataset(TRAIN_DIR)
    val_dataset = MosquitoDetectorDataset(VAL_DIR)

    print("Train windows:", len(train_dataset))
    print("Validation windows:", len(val_dataset))


    train_loader = DataLoader(
        train_dataset,
        batch_size=BATCH_SIZE,
        shuffle=True,
        num_workers=4,
        pin_memory=True
    )

    val_loader = DataLoader(
        val_dataset,
        batch_size=BATCH_SIZE,
        shuffle=False,
        num_workers=4,
        pin_memory=True
    )


    # -------------------------------------------------
    # Model
    # -------------------------------------------------

    model = get_detector_resnet(num_classes=2).to(device)

    criterion = nn.CrossEntropyLoss()

    optimizer = torch.optim.Adam(
        model.parameters(),
        lr=LEARNING_RATE
    )


    best_val_acc = 0


    # -------------------------------------------------
    # Training Loop
    # -------------------------------------------------

    for epoch in range(EPOCHS):

        model.train()

        running_loss = 0
        correct = 0
        total = 0

        for inputs, labels in train_loader:

            inputs = inputs.to(device, non_blocking=True)
            labels = labels.to(device, non_blocking=True)

            optimizer.zero_grad()

            outputs = model(inputs)

            loss = criterion(outputs, labels)

            loss.backward()

            optimizer.step()

            running_loss += loss.item()

            _, predicted = outputs.max(1)

            total += labels.size(0)
            correct += predicted.eq(labels).sum().item()


        train_acc = 100 * correct / total


        # -------------------------------------------------
        # Validation
        # -------------------------------------------------

        model.eval()

        correct = 0
        total = 0

        with torch.no_grad():

            for inputs, labels in val_loader:

                inputs = inputs.to(device, non_blocking=True)
                labels = labels.to(device, non_blocking=True)

                outputs = model(inputs)

                _, predicted = outputs.max(1)

                total += labels.size(0)
                correct += predicted.eq(labels).sum().item()


        val_acc = 100 * correct / total


        print(
            f"Epoch [{epoch+1}/{EPOCHS}] "
            f"Loss: {running_loss:.4f} "
            f"Train Acc: {train_acc:.2f}% "
            f"Val Acc: {val_acc:.2f}%"
        )


        # -------------------------------------------------
        # Save best model
        # -------------------------------------------------

        if val_acc > best_val_acc:

            best_val_acc = val_acc

            os.makedirs("weights", exist_ok=True)

            torch.save(
                model.state_dict(),
                "weights/best_mosquito_detector.pth"
            )


    print("\nBest Validation Accuracy:", best_val_acc)


if __name__ == "__main__":
    main()