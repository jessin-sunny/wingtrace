import sys
import os

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
import torch

from dataset_loader.mosquito_dataset import MosquitoDataset
from configs.config import TRAIN_DIR
from models.resnet_audio import get_mosquito_resnet


# Load dataset
dataset = MosquitoDataset(TRAIN_DIR, train=True)

print("Dataset size:", len(dataset))


# Get one sample
x, y = dataset[0]

print("Tensor shape:", x.shape)
print("Label:", y)


# Create batch dimension
x = x.unsqueeze(0)

print("Batch shape:", x.shape)


# Load model
model = get_mosquito_resnet(num_classes=3)

# Forward pass
output = model(x)

print("Model output shape:", output.shape)