from torchvision import transforms

# train_transform = transforms.Compose([
#     transforms.RandomResizedCrop(224, scale=(0.6, 1.0)),
#     transforms.RandomHorizontalFlip(),
#     transforms.RandomRotation(20),

#     transforms.ColorJitter(
#         brightness=0.4,
#         contrast=0.4,
#         saturation=0.4,
#         hue=0.1
#     ),

#     transforms.GaussianBlur(3),

#     transforms.ToTensor(),

#     transforms.Normalize(
#         mean=[0.485,0.456,0.406],
#         std=[0.229,0.224,0.225]
#     )
# ])

# val_transform = transforms.Compose([
#     transforms.Resize(256),
#     transforms.CenterCrop(224),

#     transforms.ToTensor(),

#     transforms.Normalize(
#         mean=[0.485,0.456,0.406],
#         std=[0.229,0.224,0.225]
#     )
# ])


# Efficietnet b1
# train_transform = transforms.Compose([
#     transforms.RandomResizedCrop(
#         224,
#         scale=(0.7, 1.0)
#     ),

#     transforms.RandomHorizontalFlip(p=0.5),

#     transforms.RandomRotation(25),

#     transforms.ColorJitter(
#         brightness=0.4,
#         contrast=0.4,
#         saturation=0.4,
#         hue=0.08
#     ),

#     transforms.RandomPerspective(
#         distortion_scale=0.2,
#         p=0.3
#     ),

#     transforms.GaussianBlur(kernel_size=3, sigma=(0.1, 2.0)),

#     transforms.ToTensor(),

#     transforms.RandomErasing(
#         p=0.25,
#         scale=(0.02, 0.1)
#     ),

#     transforms.Normalize(
#         mean=[0.485,0.456,0.406],
#         std=[0.229,0.224,0.225]
#     )
# ])

# val_transform = transforms.Compose([
#     transforms.Resize((224, 224)),

#     transforms.ToTensor(),

#     transforms.Normalize(
#         mean=[0.485,0.456,0.406],
#         std=[0.229,0.224,0.225]
#     )
# ])

# agrresive transform
train_transform = transforms.Compose([

    transforms.RandomResizedCrop(
        224,
        scale=(0.65,1.0)
    ),

    transforms.RandomHorizontalFlip(p=0.5),

    transforms.RandomRotation(25),

    transforms.ColorJitter(
        brightness=0.4,
        contrast=0.4,
        saturation=0.4,
        hue=0.08
    ),

    transforms.RandomPerspective(
        distortion_scale=0.25,
        p=0.35
    ),

    transforms.RandomGrayscale(p=0.15),

    transforms.GaussianBlur(
        kernel_size=3,
        sigma=(0.1,2.0)
    ),

    transforms.ToTensor(),

    transforms.RandomErasing(
        p=0.35,
        scale=(0.02,0.15)
    ),

    transforms.Normalize(
        mean=[0.485,0.456,0.406],
        std=[0.229,0.224,0.225]
    )
])

val_transform = transforms.Compose([
    transforms.Resize((224,224)),
    transforms.ToTensor(),
    transforms.Normalize(
        mean=[0.485,0.456,0.406],
        std=[0.229,0.224,0.225]
    )
])