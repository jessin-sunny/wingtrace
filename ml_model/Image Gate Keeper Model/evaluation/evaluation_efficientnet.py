import sys
import os

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import torch
import numpy as np

from sklearn.metrics import confusion_matrix, classification_report, accuracy_score

from models.efficientnet_image_gatekeeper import get_efficientnet
from utils.dataset_loader import get_dataloaders
from config import *


def evaluate():

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print("Running evaluation on:", device)

    # Load dataloaders
    train_loader, val_loader, test_loader = get_dataloaders()

    # Load model
    model = get_efficientnet()

    model.load_state_dict(
        torch.load(EFFICIENTNET_SAVE_PATH, map_location=device)
    )

    model.to(device)
    model.eval()

    all_preds = []
    all_labels = []

    with torch.no_grad():

        for images, labels in test_loader:

            images = images.to(device)
            labels = labels.to(device)

            outputs = model(images)

            _, preds = torch.max(outputs, 1)

            all_preds.extend(preds.cpu().numpy())
            all_labels.extend(labels.cpu().numpy())

    all_preds = np.array(all_preds)
    all_labels = np.array(all_labels)

    # Accuracy
    acc = accuracy_score(all_labels, all_preds)

    print("\nTest Accuracy:", acc * 100)

    # Confusion Matrix
    cm = confusion_matrix(all_labels, all_preds)

    print("\nConfusion Matrix:\n")
    print(cm)

    # Classification report
    print("\nClassification Report:\n")

    print(classification_report(
        all_labels,
        all_preds,
        target_names=CLASSES
    ))


def main():
    evaluate()


if __name__ == "__main__":
    main()