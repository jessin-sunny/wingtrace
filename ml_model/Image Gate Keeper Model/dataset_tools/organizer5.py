import os
import random
import shutil

source_dir = r"C:\Users\jessi\Downloads\archive (2)\images"

train_dir = r"C:\My\RIT\S8\Project\WingTrace\ml_model\Image Gate Keeper Model\dataset\train\neither"
val_dir = r"C:\My\RIT\S8\Project\WingTrace\ml_model\Image Gate Keeper Model\dataset\val\neither"
test_dir = r"C:\My\RIT\S8\Project\WingTrace\ml_model\Image Gate Keeper Model\dataset\test\neither"

os.makedirs(train_dir, exist_ok=True)
os.makedirs(val_dir, exist_ok=True)
os.makedirs(test_dir, exist_ok=True)

images = os.listdir(source_dir)
random.shuffle(images)

total = len(images)

train_count = int(total * 0.7)
val_count = int(total * 0.15)
test_count = total - train_count - val_count

train_images = images[:train_count]
val_images = images[train_count:train_count + val_count]
test_images = images[train_count + val_count:]

def copy_files(file_list, destination):
    for file in file_list:
        src = os.path.join(source_dir, file)
        dst = os.path.join(destination, file)
        shutil.copy(src, dst)

copy_files(train_images, train_dir)
copy_files(val_images, val_dir)
copy_files(test_images, test_dir)

print("Dataset split completed")
print(f"Train: {train_count}")
print(f"Validation: {val_count}")
print(f"Test: {test_count}")