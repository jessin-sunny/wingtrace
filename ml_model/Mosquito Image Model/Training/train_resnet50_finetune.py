import torch
import torch.nn as nn
import torch.optim as optim
from torchvision import models

from dataset_loader import get_dataloaders


def main():

    # =============================
    # LOAD DATA
    # =============================

    train_loader, val_loader, test_loader = get_dataloaders()

    # =============================
    # DEVICE
    # =============================

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print("Using device:", device)

    # =============================
    # LOAD MODEL
    # =============================

    model = models.resnet50(weights=None)

    num_features = model.fc.in_features
    model.fc = nn.Linear(num_features, 3)

    # Load previously trained weights
    model.load_state_dict(torch.load(
        r"C:\My\RIT\S8\Project\WingTrace\ml_model\Mosquito Image Model\mosquito_resnet50.pth",
        map_location=device
    ))

    # =============================
    # FREEZE EARLY LAYERS
    # =============================

    for param in model.parameters():
        param.requires_grad = False

    # Unfreeze last ResNet block
    for param in model.layer4.parameters():
        param.requires_grad = True

    # Unfreeze classifier
    for param in model.fc.parameters():
        param.requires_grad = True

    model = model.to(device)

    # =============================
    # LOSS FUNCTION
    # =============================

    criterion = nn.CrossEntropyLoss()

    # =============================
    # OPTIMIZER
    # =============================

    optimizer = optim.Adam(
        filter(lambda p: p.requires_grad, model.parameters()),
        lr=0.00005
    )

    # =============================
    # TRAINING SETTINGS
    # =============================

    epochs = 5
    best_val_acc = 0

    # =============================
    # TRAINING LOOP
    # =============================

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

        # =============================
        # VALIDATION
        # =============================

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

        # =============================
        # SAVE BEST MODEL
        # =============================

        if val_acc > best_val_acc:

            best_val_acc = val_acc

            torch.save(
                model.state_dict(),
                r"C:\My\RIT\S8\Project\WingTrace\ml_model\Mosquito Image Model\mosquito_resnet50_finetuned.pth"
            )

            print("Best model saved.")

    print("\nFine-tuning Complete")
    print("Best Validation Accuracy:", best_val_acc)


if __name__ == "__main__":
    main()