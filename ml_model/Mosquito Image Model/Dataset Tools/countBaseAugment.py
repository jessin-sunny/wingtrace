import os
from collections import defaultdict

# Dataset path
dataset_path = r"C:\My\RIT\S8\Project\Dataset\Image\Mosquito"

print("\nDATASET ANALYSIS\n")

for class_name in os.listdir(dataset_path):

    class_path = os.path.join(dataset_path, class_name)

    if not os.path.isdir(class_path):
        continue

    print(f"\nClass: {class_name}")

    total_images = 0
    base_groups = defaultdict(list)

    for file in os.listdir(class_path):

        if not file.lower().endswith((".png", ".jpg", ".jpeg")):
            continue

        total_images += 1

        name = os.path.splitext(file)[0]
        parts = name.split("_")

        # remove augmentation part
        base_name = "_".join(parts[:-1])

        base_groups[base_name].append(file)

    unique_base_images = len(base_groups)

    print("Total images           :", total_images)
    print("Unique base captures   :", unique_base_images)

    if unique_base_images > 0:
        print("Average augmentations  :", round(total_images / unique_base_images, 2))