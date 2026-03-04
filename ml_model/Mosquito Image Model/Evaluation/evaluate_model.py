import torch
import torch.nn as nn
from torchvision import models
from sklearn.metrics import classification_report, confusion_matrix
import numpy as np
import sys
import os

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from Training.dataset_loader import get_dataloaders

def main():

    train_loader, val_loader, test_loader = get_dataloaders()

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print("Using device:", device)

    # =========================
    # LOAD MODEL
    # =========================

    model = models.resnet50(weights=None)

    num_features = model.fc.in_features
    model.fc = nn.Linear(num_features, 3)

    model.load_state_dict(
        torch.load(r"C:\My\RIT\S8\Project\WingTrace\ml_model\Mosquito Image Model\mosquito_resnet50_finetuned.pth")
    )

    model = model.to(device)
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

    # =========================
    # METRICS
    # =========================

    test_accuracy = np.mean(np.array(all_preds) == np.array(all_labels)) * 100
    print("\nTest Accuracy:", test_accuracy)

    cm = confusion_matrix(all_labels, all_preds)

    print("\nConfusion Matrix:")
    print(cm)

    class_names = ["Aedes", "Anopheles", "Culex"]

    print("\nClassification Report:")
    print(classification_report(all_labels, all_preds, target_names=class_names))


if __name__ == "__main__":
    main()