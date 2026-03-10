import os
import shutil
import random
from sklearn.model_selection import train_test_split

# -----------------------
# Paths
# -----------------------

SOURCE = r"C:\My\RIT\S8\Project\Dataset\Audio\Mosquito_3000"
DEST = r"C:\My\RIT\S8\Project\WingTrace\ml_model\Mosquito Audio Model\Dataset"

# -----------------------
# Species → Genus mapping
# -----------------------

species_to_genus = {
    "Ae. aegypti": "aedes",
    "Ae. albopictus": "aedes",
    "An. arabiensis": "anopheles",
    "An. gambiae": "anopheles",
    "C. pipiens": "culex",
    "C. quinquefasciatus": "culex"
}

# -----------------------
# Split ratios
# -----------------------

TRAIN_RATIO = 0.7
VAL_RATIO = 0.15
TEST_RATIO = 0.15

# -----------------------
# Create destination folders
# -----------------------

for split in ["train", "val", "test"]:
    for genus in ["aedes", "anopheles", "culex"]:
        path = os.path.join(DEST, split, genus)
        os.makedirs(path, exist_ok=True)

# -----------------------
# Collect files per genus
# -----------------------

genus_files = {
    "aedes": [],
    "anopheles": [],
    "culex": []
}

for species, genus in species_to_genus.items():
    species_path = os.path.join(SOURCE, species)

    if not os.path.exists(species_path):
        print("Missing folder:", species_path)
        continue

    for file in os.listdir(species_path):
        if file.endswith(".wav"):
            full_path = os.path.join(species_path, file)
            genus_files[genus].append(full_path)

# -----------------------
# Split and copy files
# -----------------------

for genus, files in genus_files.items():

    random.shuffle(files)

    train_files, temp_files = train_test_split(
        files, test_size=(1 - TRAIN_RATIO), random_state=42
    )

    val_files, test_files = train_test_split(
        temp_files,
        test_size=TEST_RATIO / (TEST_RATIO + VAL_RATIO),
        random_state=42
    )

    print(f"\n{genus.upper()}")

    print("Train:", len(train_files))
    print("Val:", len(val_files))
    print("Test:", len(test_files))

    for f in train_files:
        shutil.copy(f, os.path.join(DEST, "train", genus))

    for f in val_files:
        shutil.copy(f, os.path.join(DEST, "val", genus))

    for f in test_files:
        shutil.copy(f, os.path.join(DEST, "test", genus))

print("\nDataset split completed.")