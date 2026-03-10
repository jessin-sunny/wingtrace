# config.py
import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

DATASET_PATH = os.path.join(BASE_DIR, "dataset")

BATCH_SIZE = 16
EPOCHS = 8
LR = 0.0003

IMAGE_SIZE = 224

CLASSES = [
    "mosquito",
    "noise",
    "pest"
]

NUM_CLASSES = 3

MODEL_SAVE_PATH = os.path.join(BASE_DIR, "gatekeeper_resnet18.pth")