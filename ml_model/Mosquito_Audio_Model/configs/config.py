# configs/config.py

import os

# =========================================================
# PATH CONFIGURATION
# =========================================================

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

DATASET_DIR = os.path.join(BASE_DIR, "dataset")

TRAIN_DIR = os.path.join(DATASET_DIR, "train")
VAL_DIR = os.path.join(DATASET_DIR, "val")
TEST_DIR = os.path.join(DATASET_DIR, "test")

CHECKPOINT_DIR = os.path.join(BASE_DIR, "checkpoints")
LOG_DIR = os.path.join(BASE_DIR, "logs")

# Create directories if not exist
os.makedirs(CHECKPOINT_DIR, exist_ok=True)
os.makedirs(LOG_DIR, exist_ok=True)


# =========================================================
# AUDIO PARAMETERS
# =========================================================

SAMPLE_RATE = 8000
AUDIO_DURATION = 0.625  # seconds

N_FFT = 1024
HOP_LENGTH = 256
N_MELS = 128

WINDOW_FRAMES = 19  # 0.625s ≈ 19 frames


# =========================================================
# DATASET SETTINGS
# =========================================================

CLASSES = [
    "Aedes",
    "Anopheles",
    "Culex"
]

NUM_CLASSES = len(CLASSES)


# =========================================================
# AUGMENTATION PROBABILITIES
# =========================================================

AUG_NONE = 0.45
AUG_NOISE = 0.20
AUG_GAIN = 0.15
AUG_SHIFT = 0.10
AUG_STRETCH = 0.10


# =========================================================
# TRAINING SETTINGS
# =========================================================

BATCH_SIZE = 32
EPOCHS = 30
LEARNING_RATE = 0.0003

NUM_WORKERS = 4

DROPOUT = 0.2


# =========================================================
# MODEL SETTINGS
# =========================================================

MODEL_NAME = "resnet18"

INPUT_CHANNELS = 1
INPUT_HEIGHT = 128
INPUT_WIDTH = 19