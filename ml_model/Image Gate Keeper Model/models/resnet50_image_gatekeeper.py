import torch.nn as nn
from torchvision import models
from config import NUM_CLASSES


def get_resnet50():

    model = models.resnet50(
        weights=models.ResNet50_Weights.IMAGENET1K_V1
    )

    # Freeze backbone
    for param in model.parameters():
        param.requires_grad = False

    num_features = model.fc.in_features

    # Replace final layer
    model.fc = nn.Linear(num_features, NUM_CLASSES)

    return model