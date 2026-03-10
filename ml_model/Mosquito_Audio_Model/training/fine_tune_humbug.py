import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import torch
import torch.nn as nn
from torch.utils.data import DataLoader

from models.resnet_audio import get_mosquito_resnet
from dataset_loader.humbug_dataset import HumBugDataset


TRAIN_DIR = r"C:\My\RIT\S8\Project\Dataset\Audio\HumBug_Genus\train"
TEST_DIR  = r"C:\My\RIT\S8\Project\Dataset\Audio\HumBug_Genus\test"


def main():

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print("Using device:", device)

    # -----------------------------
    # Dataset
    # -----------------------------

    train_dataset = HumBugDataset(TRAIN_DIR)
    test_dataset  = HumBugDataset(TEST_DIR)

    train_loader = DataLoader(
        train_dataset,
        batch_size=32,
        shuffle=True,
        num_workers=4,
        pin_memory=True
    )

    test_loader = DataLoader(
        test_dataset,
        batch_size=32,
        shuffle=False,
        num_workers=4,
        pin_memory=True
    )

    # -----------------------------
    # Model
    # -----------------------------

    model = get_mosquito_resnet(num_classes=3)

    model.load_state_dict(
        torch.load(
            r"C:\My\RIT\S8\Project\WingTrace\ml_model\Mosquito Audio Model\best_mosquito_audio_model.pth"
        )
    )

    model = model.to(device)

    # -----------------------------
    # Freeze early layers
    # -----------------------------

    for param in model.layer1.parameters():
        param.requires_grad = False

    for param in model.layer2.parameters():
        param.requires_grad = False

    # -----------------------------
    # Training Setup
    # -----------------------------

    criterion = nn.CrossEntropyLoss()

    optimizer = torch.optim.Adam(
        filter(lambda p: p.requires_grad, model.parameters()),
        lr=1e-4
    )

    EPOCHS = 10

    # -----------------------------
    # Training Loop
    # -----------------------------

    for epoch in range(EPOCHS):

        model.train()

        correct = 0
        total = 0
        running_loss = 0

        for x, y in train_loader:

            x = x.to(device)
            y = y.to(device)

            optimizer.zero_grad()

            outputs = model(x)

            loss = criterion(outputs, y)

            loss.backward()

            optimizer.step()

            running_loss += loss.item()

            _, pred = torch.max(outputs, 1)

            total += y.size(0)
            correct += (pred == y).sum().item()

        train_acc = correct / total

        # -----------------------------
        # Validation
        # -----------------------------

        model.eval()

        correct = 0
        total = 0

        with torch.no_grad():

            for x, y in test_loader:

                x = x.to(device)
                y = y.to(device)

                outputs = model(x)

                _, pred = torch.max(outputs, 1)

                total += y.size(0)
                correct += (pred == y).sum().item()

        val_acc = correct / total

        print(
            f"Epoch {epoch+1}/{EPOCHS} | "
            f"Loss: {running_loss:.2f} | "
            f"Train Acc: {train_acc:.4f} | "
            f"Val Acc: {val_acc:.4f}"
        )

    # -----------------------------
    # Save model
    # -----------------------------

    torch.save(
        model.state_dict(),
        "mosquito_humbug_finetuned.pth"
    )

    print("Fine-tuned model saved.")


# Required for Windows multiprocessing
if __name__ == "__main__":
    main()