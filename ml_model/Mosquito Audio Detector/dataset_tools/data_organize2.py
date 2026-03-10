import os
import shutil
import random

# -----------------------------
# PATHS
# -----------------------------

mosquito_root = r"C:\My\RIT\S8\Project\Dataset\Audio\Mosquito_3000"
noise_root = r"C:\My\RIT\S8\Project\Dataset\Audio\Noise"

dataset_root = r"C:\My\RIT\S8\Project\WingTrace\ml_model\Mosquito Audio Detector\dataset"

# -----------------------------
# SPLIT VALUES
# -----------------------------

mosquito_train = 2100
mosquito_val = 450
mosquito_test = 450

noise_train = 1273
noise_val = 273
noise_test = 273

# -----------------------------
# CREATE FOLDERS
# -----------------------------

splits = ["train", "val", "test"]
classes = ["mosquito", "noise"]

for s in splits:
    for c in classes:
        os.makedirs(os.path.join(dataset_root, s, c), exist_ok=True)

# -----------------------------
# MOSQUITO SPLIT
# -----------------------------

print("Processing mosquito dataset...")

for class_name in os.listdir(mosquito_root):

    class_path = os.path.join(mosquito_root, class_name)

    if not os.path.isdir(class_path):
        continue

    files = os.listdir(class_path)
    random.shuffle(files)

    train_files = files[:mosquito_train]
    val_files = files[mosquito_train:mosquito_train + mosquito_val]
    test_files = files[mosquito_train + mosquito_val:mosquito_train + mosquito_val + mosquito_test]

    for f in train_files:
        src = os.path.join(class_path, f)
        dst = os.path.join(dataset_root, "train", "mosquito", f)
        shutil.copy(src, dst)

    for f in val_files:
        src = os.path.join(class_path, f)
        dst = os.path.join(dataset_root, "val", "mosquito", f)
        shutil.copy(src, dst)

    for f in test_files:
        src = os.path.join(class_path, f)
        dst = os.path.join(dataset_root, "test", "mosquito", f)
        shutil.copy(src, dst)

print("Mosquito dataset split complete.")

# -----------------------------
# NOISE SPLIT
# -----------------------------

print("Processing noise dataset...")

noise_files = os.listdir(noise_root)
random.shuffle(noise_files)

train_noise = noise_files[:noise_train]
val_noise = noise_files[noise_train:noise_train + noise_val]
test_noise = noise_files[noise_train + noise_val:noise_train + noise_val + noise_test]

for f in train_noise:
    shutil.copy(
        os.path.join(noise_root, f),
        os.path.join(dataset_root, "train", "noise", f)
    )

for f in val_noise:
    shutil.copy(
        os.path.join(noise_root, f),
        os.path.join(dataset_root, "val", "noise", f)
    )

for f in test_noise:
    shutil.copy(
        os.path.join(noise_root, f),
        os.path.join(dataset_root, "test", "noise", f)
    )

print("Noise dataset split complete.")

print("Dataset organization finished.")