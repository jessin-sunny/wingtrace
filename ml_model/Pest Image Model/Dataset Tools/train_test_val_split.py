import os
import random
import shutil

# SOURCE DATASET (your class folders)
source_dir = r"C:\My\RIT\S8\Project\Dataset\Image\Pest - Latest"

# DESTINATION
dest_dir = r"C:\My\RIT\S8\Project\WingTrace\ml_model\Pest Image Model\Dataset"

# split ratios
train_ratio = 0.7
val_ratio = 0.15
test_ratio = 0.15

# create folders
for split in ["train", "val", "test"]:
    os.makedirs(os.path.join(dest_dir, split), exist_ok=True)

classes = os.listdir(source_dir)

for cls in classes:

    class_path = os.path.join(source_dir, cls)
    images = os.listdir(class_path)

    random.shuffle(images)

    total = len(images)

    train_end = int(train_ratio * total)
    val_end = train_end + int(val_ratio * total)

    train_images = images[:train_end]
    val_images = images[train_end:val_end]
    test_images = images[val_end:]

    # create class folders
    os.makedirs(os.path.join(dest_dir, "train", cls), exist_ok=True)
    os.makedirs(os.path.join(dest_dir, "val", cls), exist_ok=True)
    os.makedirs(os.path.join(dest_dir, "test", cls), exist_ok=True)

    # copy files
    for img in train_images:
        shutil.copy(
            os.path.join(class_path, img),
            os.path.join(dest_dir, "train", cls, img)
        )

    for img in val_images:
        shutil.copy(
            os.path.join(class_path, img),
            os.path.join(dest_dir, "val", cls, img)
        )

    for img in test_images:
        shutil.copy(
            os.path.join(class_path, img),
            os.path.join(dest_dir, "test", cls, img)
        )

    print(f"{cls} → Train:{len(train_images)}  Val:{len(val_images)}  Test:{len(test_images)}")

print("\nDataset splitting completed successfully.")