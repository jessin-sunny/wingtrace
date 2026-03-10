import torch.nn as nn
from torchvision import models
from config import NUM_CLASSES


def get_resnet18():

    model = models.resnet18(
        weights=models.ResNet18_Weights.IMAGENET1K_V1
    )

    num_features = model.fc.in_features

    model.fc = nn.Sequential(
        nn.Linear(num_features, 256),
        nn.ReLU(),
        nn.Dropout(0.4),
        nn.Linear(256, NUM_CLASSES)
    )

    return model