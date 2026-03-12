import sys
import os

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import torch
import numpy as np
from torchvision import datasets, transforms
from torch.utils.data import DataLoader

from sklearn.metrics import confusion_matrix, classification_report, accuracy_score

from models.resnet50_image_gatekeeper import get_resnet50
from config import MODEL_SAVE_PATH, CLASSES


def evaluate_unseen():

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print("Running on:", device)

    unseen_path = r"C:\My\RIT\S8\Project\Dataset\Image\Gate - Unseen"

    transform = transforms.Compose([
        transforms.Resize((224,224)),
        transforms.ToTensor(),
        transforms.Normalize(
            mean=[0.485,0.456,0.406],
            std=[0.229,0.224,0.225]
        )
    ])

    dataset = datasets.ImageFolder(
        root=unseen_path,
        transform=transform
    )

    loader = DataLoader(
        dataset,
        batch_size=32,
        shuffle=False
    )

    print("Classes detected:", dataset.classes)

    model = get_resnet50()

    model.load_state_dict(
        torch.load(MODEL_SAVE_PATH, map_location=device)
    )

    model.to(device)
    model.eval()

    all_preds = []
    all_labels = []

    with torch.no_grad():

        for images, labels in loader:

            images = images.to(device)

            outputs = model(images)

            _, preds = torch.max(outputs, 1)

            all_preds.extend(preds.cpu().numpy())
            all_labels.extend(labels.numpy())

    all_preds = np.array(all_preds)
    all_labels = np.array(all_labels)

    # Accuracy
    acc = accuracy_score(all_labels, all_preds)

    print("\nAccuracy:", acc*100)

    # Confusion Matrix
    cm = confusion_matrix(all_labels, all_preds)

    print("\nConfusion Matrix:\n")
    print(cm)

    # Classification Report
    print("\nPrecision / Recall / F1\n")

    print(classification_report(
        all_labels,
        all_preds,
        target_names=dataset.classes
    ))


if __name__ == "__main__":
    evaluate_unseen()