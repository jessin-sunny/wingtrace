import os
import shutil
import random
from collections import defaultdict

# =====================================
# INPUT DATASET PATH
# =====================================

input_dir = r"C:\Users\jessi\Downloads\archive"

# =====================================
# OUTPUT DATASET PATH
# =====================================

output_dir = r"C:\My\RIT\S8\Project\Dataset\Image\Mosquito"

# =====================================
# SPECIES → GENUS MAPPING
# =====================================

species_to_genus = {
    "Ae-aegypti": "Aedes",
    "Ae-albopictus": "Aedes",
    "Ae-vexans": "Aedes",

    "An-tessellatus": "Anopheles",

    "Cx-quinquefasciatus": "Culex",
    "Cx-vishnui": "Culex"
}

# =====================================
# TARGET IMAGE COUNT PER SPECIES
# =====================================

target_species = {
    "Ae-aegypti": 2333,
    "Ae-albopictus": 2333,
    "Ae-vexans": 2334,

    "An-tessellatus": 7000,

    "Cx-quinquefasciatus": 3500,
    "Cx-vishnui": 3500
}

# =====================================
# FUNCTION TO REMOVE AUGMENTATION TAG
# =====================================

def get_base_name(filename):
    name = os.path.splitext(filename)[0]
    parts = name.split("_")
    return "_".join(parts[:-1])

# =====================================
# CREATE OUTPUT GENUS FOLDERS
# =====================================

for genus in ["Aedes", "Anopheles", "Culex"]:
    os.makedirs(os.path.join(output_dir, genus), exist_ok=True)

# =====================================
# PROCESS EACH SPECIES
# =====================================

for species in species_to_genus:

    print(f"\nProcessing species: {species}")

    species_path = os.path.join(input_dir, species)

    genus = species_to_genus[species]

    target = target_species[species]

    groups = defaultdict(list)

    # ==============================
    # GROUP IMAGES BY BASE CAPTURE
    # ==============================

    for file in os.listdir(species_path):

        if not file.lower().endswith((".png", ".jpg", ".jpeg")):
            continue

        base = get_base_name(file)

        groups[base].append(file)

    base_keys = list(groups.keys())

    print("Base captures found:", len(base_keys))

    selected = []

    # ==============================
    # STEP 1: TAKE ALL BASE IMAGES
    # ==============================

    for key in base_keys:
        selected.append(groups[key][0])

    # ==============================
    # STEP 2: ADD AUGMENTED IMAGES
    # ==============================

    if len(selected) < target:

        aug_pool = []

        for key in base_keys:
            aug_pool.extend(groups[key][1:])

        random.shuffle(aug_pool)

        remaining = target - len(selected)

        selected.extend(aug_pool[:remaining])

    # ==============================
    # COPY FILES TO GENUS FOLDER
    # ==============================

    print("Images selected:", len(selected))

    for file in selected:

        src = os.path.join(species_path, file)

        dst = os.path.join(output_dir, genus, file)

        shutil.copy(src, dst)

print("\nDataset creation completed successfully.")