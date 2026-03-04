import torch
import torch.nn as nn
from torchvision import models
from sklearn.metrics import classification_report, confusion_matrix
import numpy as np
import sys
import os

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from Training.dataset_loader_augmentation import get_dataloaders

def main():

    # ---------------------------------
    # Dataset path
    # ---------------------------------

    dataset_root = r"C:\My\RIT\S8\Project\WingTrace\ml_model\Pest Image Model\Dataset"

    train_loader, val_loader, test_loader = get_dataloaders(dataset_root)


    # ---------------------------------
    # Class Names
    # ---------------------------------

    class_names = [
        "Cicadellidae",
        "Lycorma delicatula",
        "Miridae",
        "aphids",
        "blister beetle",
        "corn borer",
        "whitefly"
    ]


    # ---------------------------------
    # Device
    # ---------------------------------

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    print("Using device:", device)


    # ---------------------------------
    # Load model
    # ---------------------------------

    model = models.resnet50(weights=None)

    num_classes = 7

    model.fc = nn.Linear(model.fc.in_features, num_classes)

    model.load_state_dict(torch.load(r"C:\My\RIT\S8\Project\WingTrace\ml_model\Pest Image Model\pest_resnet50_finetuned.pth"))

    model = model.to(device)

    model.eval()


    # ---------------------------------
    # Evaluation
    # ---------------------------------

    all_preds = []
    all_labels = []

    with torch.no_grad():

        for images, labels in test_loader:

            images = images.to(device)
            labels = labels.to(device)

            outputs = model(images)

            _, predicted = torch.max(outputs, 1)

            all_preds.extend(predicted.cpu().numpy())
            all_labels.extend(labels.cpu().numpy())


    # ---------------------------------
    # Classification Report
    # ---------------------------------

    print("\nClassification Report:\n")

    print(
        classification_report(
            all_labels,
            all_preds,
            target_names=class_names
        )
    )


    # ---------------------------------
    # Confusion Matrix
    # ---------------------------------

    print("\nConfusion Matrix:\n")

    cm = confusion_matrix(all_labels, all_preds)

    print(cm)


if __name__ == "__main__":
    main()