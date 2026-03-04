import torch
import torch.nn as nn
import torch.optim as optim
from torchvision import models

from dataset_loader_augmentation import get_dataloaders


def main():

    # -----------------------------
    # Dataset Path
    # -----------------------------

    dataset_root = r"C:\My\RIT\S8\Project\WingTrace\ml_model\Pest Image Model\Dataset"


    # -----------------------------
    # Load Data
    # -----------------------------

    train_loader, val_loader, test_loader = get_dataloaders(dataset_root)


    # -----------------------------
    # Device
    # -----------------------------

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    print("Using device:", device)


    # -----------------------------
    # Load ResNet50
    # -----------------------------

    model = models.resnet50(weights=models.ResNet50_Weights.IMAGENET1K_V1)

    num_classes = 7

    model.fc = nn.Linear(model.fc.in_features, num_classes)

    model = model.to(device)


    # -----------------------------
    # Freeze Backbone
    # -----------------------------

    for param in model.parameters():
        param.requires_grad = False

    for param in model.fc.parameters():
        param.requires_grad = True


    # -----------------------------
    # Loss
    # -----------------------------

    criterion = nn.CrossEntropyLoss()


    # -----------------------------
    # Optimizer
    # -----------------------------

    optimizer = optim.Adam(model.fc.parameters(), lr=0.001)


    # -----------------------------
    # Training Settings
    # -----------------------------

    epochs = 15
    best_val_acc = 0


    # -----------------------------
    # Training Loop
    # -----------------------------

    for epoch in range(epochs):

        model.train()

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

            _, predicted = torch.max(outputs, 1)

            total += labels.size(0)
            correct += (predicted == labels).sum().item()


        train_acc = 100 * correct / total


        # -----------------------------
        # Validation
        # -----------------------------

        model.eval()

        val_correct = 0
        val_total = 0

        with torch.no_grad():

            for images, labels in val_loader:

                images = images.to(device)
                labels = labels.to(device)

                outputs = model(images)

                _, predicted = torch.max(outputs, 1)

                val_total += labels.size(0)
                val_correct += (predicted == labels).sum().item()


        val_acc = 100 * val_correct / val_total


        print(f"Epoch {epoch+1}/{epochs}")
        print(f"Train Accuracy: {train_acc:.2f}%")
        print(f"Validation Accuracy: {val_acc:.2f}%")
        print("-----------------------------------")


        # Save best model

        if val_acc > best_val_acc:

            best_val_acc = val_acc

            torch.save(model.state_dict(), "pest_resnet50.pth")

            print("Best model saved\n")


    print("Training finished")
    print("Best Validation Accuracy:", best_val_acc)



# -------------------------------------------------
# Required for Windows multiprocessing
# -------------------------------------------------

if __name__ == "__main__":
    main()