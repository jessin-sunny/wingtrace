import torch.nn as nn
from torchvision import models
from config import NUM_CLASSES


def get_efficientnet():

    model = models.efficientnet_b1(
        weights=models.EfficientNet_B1_Weights.IMAGENET1K_V1
    )

    num_features = model.classifier[1].in_features

    model.classifier = nn.Sequential(
        nn.Dropout(0.4),
        nn.Linear(num_features, NUM_CLASSES)
    )

    return model