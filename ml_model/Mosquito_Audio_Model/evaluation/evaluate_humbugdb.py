import sys
import os

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import torch
from torch.utils.data import DataLoader
from sklearn.metrics import confusion_matrix, classification_report
import numpy as np

from dataset_loader.mosquito_dataset import MosquitoDataset
from models.resnet_audio import get_mosquito_resnet
from configs.config import BATCH_SIZE, CLASSES


# -------------------------------------------------
# PATHS
# -------------------------------------------------

TEST_DIR = r"C:\My\RIT\S8\Project\Dataset\Audio\HumBug_Genus\test"

MODEL_PATH = r"C:\My\RIT\S8\Project\WingTrace\ml_model\Mosquito Audio Model\best_mosquito_audio_model.pth"


def main():

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    print("Using device:", device)

    # -------------------------------------------------
    # DATASET
    # -------------------------------------------------

    test_dataset = MosquitoDataset(TEST_DIR, train=False)

    test_loader = DataLoader(
        test_dataset,
        batch_size=BATCH_SIZE,
        shuffle=False,
        num_workers=4,
        pin_memory=True
    )

    # -------------------------------------------------
    # MODEL
    # -------------------------------------------------

    model = get_mosquito_resnet(num_classes=3)

    model.load_state_dict(torch.load(MODEL_PATH, map_location=device))

    model = model.to(device)

    model.eval()

    # -------------------------------------------------
    # INFERENCE
    # -------------------------------------------------

    all_preds = []
    all_labels = []

    with torch.no_grad():

        for inputs, labels in test_loader:

            inputs = inputs.to(device)

            outputs = model(inputs)

            _, preds = torch.max(outputs, 1)

            all_preds.extend(preds.cpu().numpy())
            all_labels.extend(labels.numpy())

    # -------------------------------------------------
    # METRICS
    # -------------------------------------------------

    all_preds = np.array(all_preds)
    all_labels = np.array(all_labels)

    accuracy = (all_preds == all_labels).mean()

    print("\nTest Accuracy:", accuracy)

    cm = confusion_matrix(all_labels, all_preds)

    print("\nConfusion Matrix:")
    print(cm)

    print("\nClassification Report:")
    print(classification_report(all_labels, all_preds, target_names=CLASSES))


if __name__ == "__main__":
    main()