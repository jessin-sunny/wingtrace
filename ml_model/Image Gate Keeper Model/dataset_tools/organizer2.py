# import os
# import shutil

# src_train = r"C:\My\RIT\S8\Project\WingTrace\ml_model\Mosquito Image Model\Dataset\train\Anopheles"
# src_val = r"C:\My\RIT\S8\Project\WingTrace\ml_model\Mosquito Image Model\Dataset\val\Anopheles"
# src_test = r"C:\My\RIT\S8\Project\WingTrace\ml_model\Mosquito Image Model\Dataset\test\Anopheles"

# dst_train = r"C:\My\RIT\S8\Project\WingTrace\ml_model\Image Gate Keeper Model\dataset\train\mosquito"
# dst_val = r"C:\My\RIT\S8\Project\WingTrace\ml_model\Image Gate Keeper Model\dataset\val\mosquito"
# dst_test = r"C:\My\RIT\S8\Project\WingTrace\ml_model\Image Gate Keeper Model\dataset\test\mosquito"

# os.makedirs(dst_train, exist_ok=True)
# os.makedirs(dst_val, exist_ok=True)
# os.makedirs(dst_test, exist_ok=True)

# def copy_all(src, dst):
#     for f in os.listdir(src):
#         shutil.copy(os.path.join(src, f), os.path.join(dst, f))

# copy_all(src_train, dst_train)
# copy_all(src_val, dst_val)
# copy_all(src_test, dst_test)

# print("Culex copied successfully")

import os
import random
import shutil
from collections import defaultdict

random.seed(42)

source_root = r"C:\My\RIT\S8\Project\Dataset\Image\Mosquito"

target_root = r"C:\My\RIT\S8\Project\WingTrace\ml_model\Image Gate Keeper Model\dataset"

train_dir = os.path.join(target_root, "train", "mosquito")
val_dir   = os.path.join(target_root, "val", "mosquito")
test_dir  = os.path.join(target_root, "test", "mosquito")

os.makedirs(train_dir, exist_ok=True)
os.makedirs(val_dir, exist_ok=True)
os.makedirs(test_dir, exist_ok=True)

print("\nSplitting dataset using UNIQUE captures\n")

for genus in os.listdir(source_root):

    genus_path = os.path.join(source_root, genus)

    if not os.path.isdir(genus_path):
        continue

    print(f"\nProcessing genus: {genus}")

    base_groups = defaultdict(list)

    for file in os.listdir(genus_path):

        if not file.lower().endswith((".png",".jpg",".jpeg",".webp")):
            continue

        name = os.path.splitext(file)[0]

        parts = name.split("_")

        base_name = "_".join(parts[:-1])

        base_groups[base_name].append(file)

    print("Unique captures:", len(base_groups))

    unique_images = []

    for base_name, files in base_groups.items():

        chosen = None

        for f in files:
            if f.endswith("_A0.png") or f.endswith("_A0.jpg"):
                chosen = f
                break

        if chosen is None:
            chosen = files[0]

        unique_images.append(chosen)

    random.shuffle(unique_images)

    total = len(unique_images)

    train_split = int(0.70 * total)
    val_split   = int(0.15 * total)

    train_imgs = unique_images[:train_split]
    val_imgs   = unique_images[train_split:train_split+val_split]
    test_imgs  = unique_images[train_split+val_split:]

    def copy_files(files, target):

        for f in files:

            src = os.path.join(genus_path, f)
            dst = os.path.join(target, f"{genus}_{f}")

            shutil.copy(src, dst)

    copy_files(train_imgs, train_dir)
    copy_files(val_imgs, val_dir)
    copy_files(test_imgs, test_dir)

    print(
        f"{genus} -> Train:{len(train_imgs)} "
        f"Val:{len(val_imgs)} "
        f"Test:{len(test_imgs)}"
    )

print("\nDataset split completed.")