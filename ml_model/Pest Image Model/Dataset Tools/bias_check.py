import os
import random
import matplotlib.pyplot as plt
from PIL import Image

dataset_path = r"C:\My\RIT\S8\Project\Dataset\Image\Pest - Latest"

classes = os.listdir(dataset_path)

for cls in classes:
    class_path = os.path.join(dataset_path, cls)
    images = os.listdir(class_path)

    sample_images = random.sample(images, min(5, len(images)))

    plt.figure(figsize=(12,3))
    for i, img_name in enumerate(sample_images):
        img_path = os.path.join(class_path, img_name)
        img = Image.open(img_path)

        plt.subplot(1,5,i+1)
        plt.imshow(img)
        plt.axis("off")

    plt.suptitle(cls)
    plt.show()