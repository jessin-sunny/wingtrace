import os
import random
import shutil

source_train = r"C:\Users\jessi\Downloads\archive (1)\seg_train\seg_train"
source_test = r"C:\Users\jessi\Downloads\archive (1)\seg_test\seg_test"

train_out = r"C:\My\RIT\S8\Project\WingTrace\ml_model\Image Gate Keeper Model\dataset\train\neither"
val_out = r"C:\My\RIT\S8\Project\WingTrace\ml_model\Image Gate Keeper Model\dataset\val\neither"
test_out = r"C:\My\RIT\S8\Project\WingTrace\ml_model\Image Gate Keeper Model\dataset\test\neither"

os.makedirs(train_out, exist_ok=True)
os.makedirs(val_out, exist_ok=True)
os.makedirs(test_out, exist_ok=True)

sources = [source_train, source_test]

for src in sources:

    for subclass in os.listdir(src):

        subclass_path = os.path.join(src, subclass)

        if not os.path.isdir(subclass_path):
            continue

        images = [f for f in os.listdir(subclass_path)
                  if f.lower().endswith((".jpg",".jpeg",".png"))]

        random.shuffle(images)

        total = len(images)

        train_split = int(0.70 * total)
        val_split = int(0.15 * total)

        train_imgs = images[:train_split]
        val_imgs = images[train_split:train_split+val_split]
        test_imgs = images[train_split+val_split:]

        for img in train_imgs:
            shutil.copy(
                os.path.join(subclass_path, img),
                os.path.join(train_out, f"{subclass}_{img}")
            )

        for img in val_imgs:
            shutil.copy(
                os.path.join(subclass_path, img),
                os.path.join(val_out, f"{subclass}_{img}")
            )

        for img in test_imgs:
            shutil.copy(
                os.path.join(subclass_path, img),
                os.path.join(test_out, f"{subclass}_{img}")
            )

        print(f"{subclass} -> Train:{len(train_imgs)} Val:{len(val_imgs)} Test:{len(test_imgs)}")

print("neither dataset split finished")