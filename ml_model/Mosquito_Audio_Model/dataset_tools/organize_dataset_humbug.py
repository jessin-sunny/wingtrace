import os
import shutil
import pandas as pd

# CSV metadata file
csv_path = r"C:\My\RIT\S8\Project\Dataset\Audio\HumBugDB_dataset\neurips_2021_zenodo_0_0_1.csv"

# Root directory containing dataset folders
dataset_root = r"C:\My\RIT\S8\Project\Dataset\Audio\HumBugDB_dataset"

# Output directory
output_root = r"C:\My\RIT\S8\Project\Dataset\Audio\HumBug_Genus"

# Target species mapping to genus
species_map = {
    "ae aegypti": "Aedes",
    "ae albopictus": "Aedes",
    "an arabiensis": "Anopheles",
    "an gambiae": "Anopheles",
    "culex pipiens complex": "Culex",
    "culex quinquefasciatus": "Culex"
}

# Create output folders
for genus in ["Aedes", "Anopheles", "Culex"]:
    os.makedirs(os.path.join(output_root, genus), exist_ok=True)

# Load CSV
df = pd.read_csv(csv_path)

# Filter required species
filtered = df[df["species"].isin(species_map.keys())]

print("Total filtered samples:", len(filtered))

# Dataset folders
dataset_folders = [
    "humbugdb_neurips_2021_1",
    "humbugdb_neurips_2021_2",
    "humbugdb_neurips_2021_3",
    "humbugdb_neurips_2021_4"
]

# Copy files
copied = 0
missing = 0

for _, row in filtered.iterrows():

    file_id = str(row["id"])
    species = row["species"]
    genus = species_map[species]

    filename = file_id + ".wav"

    found = False

    for folder in dataset_folders:

        src = os.path.join(dataset_root, folder, filename)

        if os.path.exists(src):

            dst = os.path.join(output_root, genus, filename)

            shutil.copy(src, dst)

            copied += 1
            found = True
            break

    if not found:
        missing += 1

print("Copied files:", copied)
print("Missing files:", missing)
print("Finished organizing dataset.")