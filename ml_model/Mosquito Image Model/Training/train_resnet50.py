import torch
import torch.nn as nn
import torch.optim as optim
from torchvision import models
from dataset_loader import get_dataloaders


def main():

    train_loader, val_loader, test_loader = get_dataloaders()

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print("Using device:", device)

    model = models.resnet50(weights=models.ResNet50_Weights.IMAGENET1K_V1)

    # Freeze backbone
    for param in model.parameters():
        param.requires_grad = False

    num_features = model.fc.in_features
    model.fc = nn.Linear(num_features, 3)

    model = model.to(device)

    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.fc.parameters(), lr=0.0003)

    epochs = 15
    best_val_acc = 0

    for epoch in range(epochs):

        print(f"\nEpoch {epoch+1}/{epochs}")

        model.train()

        running_loss = 0
        correct = 0
        total = 0

        for images, labels in train_loader:

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

        train_acc = 100 * correct / total

        print("Training Loss:", running_loss / len(train_loader))
        print("Training Accuracy:", train_acc)

        # VALIDATION

        model.eval()

        correct = 0
        total = 0

        with torch.no_grad():

            for images, labels in val_loader:

                images = images.to(device)
                labels = labels.to(device)

                outputs = model(images)

                _, predicted = torch.max(outputs, 1)

                total += labels.size(0)
                correct += (predicted == labels).sum().item()

        val_acc = 100 * correct / total

        print("Validation Accuracy:", val_acc)

        if val_acc > best_val_acc:

            best_val_acc = val_acc

            torch.save(model.state_dict(), "mosquito_resnet50.pth")

            print("Best model saved.")

    print("\nTraining Complete.")
    print("Best Validation Accuracy:", best_val_acc)


if __name__ == "__main__":
    main()