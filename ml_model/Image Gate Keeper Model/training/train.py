import sys
import os

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import torch
import torch.nn as nn
import torch.optim as optim

from models.resnet18_image_gatekeeper import get_resnet18
from utils.dataset_loader import get_dataloaders
from config import *

from tqdm import tqdm


def train_one_epoch(model, loader, criterion, optimizer, device):

    model.train()

    running_loss = 0
    correct = 0
    total = 0

    for images, labels in tqdm(loader):

        images = images.to(device)
        labels = labels.to(device)

        optimizer.zero_grad()

        outputs = model(images)

        loss = criterion(outputs, labels)

        loss.backward()

        optimizer.step()

        running_loss += loss.item()

        _, predicted = torch.max(outputs, 1)

        total += labels.size(0)
        correct += (predicted == labels).sum().item()

    epoch_loss = running_loss / len(loader)
    accuracy = 100 * correct / total

    return epoch_loss, accuracy


def validate(model, loader, criterion, device):

    model.eval()

    running_loss = 0
    correct = 0
    total = 0

    with torch.no_grad():

        for images, labels in loader:

            images = images.to(device)
            labels = labels.to(device)

            outputs = model(images)

            loss = criterion(outputs, labels)

            running_loss += loss.item()

            _, predicted = torch.max(outputs, 1)

            total += labels.size(0)
            correct += (predicted == labels).sum().item()

    epoch_loss = running_loss / len(loader)
    accuracy = 100 * correct / total

    return epoch_loss, accuracy


def main():

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    print("Device:", device)

    train_loader, val_loader, test_loader = get_dataloaders()

    model = get_resnet18().to(device)

    criterion = nn.CrossEntropyLoss()

    optimizer = optim.Adam(
        model.parameters(),
        lr=LR
    )

    scheduler = optim.lr_scheduler.StepLR(
        optimizer,
        step_size=7,
        gamma=0.1
    )

    best_val_acc = 0

    for epoch in range(EPOCHS):

        print(f"\nEpoch [{epoch+1}/{EPOCHS}]")

        train_loss, train_acc = train_one_epoch(
            model,
            train_loader,
            criterion,
            optimizer,
            device
        )

        val_loss, val_acc = validate(
            model,
            val_loader,
            criterion,
            device
        )

        scheduler.step()

        print(f"Train Loss: {train_loss:.4f} | Train Acc: {train_acc:.2f}%")
        print(f"Val Loss: {val_loss:.4f} | Val Acc: {val_acc:.2f}%")

        if val_acc > best_val_acc:

            best_val_acc = val_acc

            torch.save(
                model.state_dict(),
                MODEL_SAVE_PATH
            )

            print("Model saved!")

    print("\nTraining finished")
    print("Best Validation Accuracy:", best_val_acc)


if __name__ == "__main__":
    main()