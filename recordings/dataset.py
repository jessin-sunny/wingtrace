import os
import shutil
import pandas as pd
from collections import defaultdict

# ===== PATHS (USE RAW STRING r"" FOR WINDOWS) =====
csv_path = r"C:\My\RIT\S8\Project\Dataset\Audio\Insect-Pest-Sounds-inventory_1.csv"
audio_folder = r"C:\My\RIT\S8\Project\Dataset\Audio\Pest"
output_folder = r"C:\My\RIT\S8\Project\Dataset\Audio\Pest 2.0"

# ===== LOAD CSV =====
df = pd.read_csv(csv_path)

# ===== CLEAN FILE ID COLUMN =====
df["File ID"] = df["File ID"].astype(str)
df["File ID"] = df["File ID"].str.replace(".", "", regex=False)
df["File ID"] = df["File ID"].str.strip()

# ===== REMOVE AEDES (MOSQUITO MODEL SEPARATE) =====
df = df[~df["Description"].str.contains("Aedes", case=False, na=False)]

# ===== CLASS ASSIGNMENT FUNCTION =====
def assign_class(description):

    description = description.lower()

    if any(x in description for x in ["termite", "reticulitermes", "coptotermes"]):
        return "termites"

    elif any(x in description for x in ["sitophilus", "prostephanus", "plodia"]):
        return "stored_product"

    elif any(x in description for x in [
        "anoplophora", "monochamus", "hylotrupes",
        "buprestid", "mallodon"
    ]):
        return "wood_borers"

    elif any(x in description for x in [
        "musca", "ceratitis", "bactrocera",
        "delia", "anastrepha"
    ]):
        return "flying_pests"

    elif any(x in description for x in [
        "diaprepes", "rhynchophorus", "oryctes",
        "dermolepida", "antitrogus", "cephus"
    ]):
        return "soil_root_pests"

    else:
        return None


# ===== CREATE OUTPUT FOLDERS =====
classes = [
    "termites",
    "stored_product",
    "wood_borers",
    "flying_pests",
    "soil_root_pests"
]

for cls in classes:
    os.makedirs(os.path.join(output_folder, cls), exist_ok=True)

# ===== CREATE LOOKUP DICTIONARY =====
fileid_to_desc = dict(zip(df["File ID"], df["Description"]))

# ===== PROCESS FILES =====
class_counter = defaultdict(int)
unmatched_files = []

for filename in os.listdir(audio_folder):

    name = filename.split(".")[0]
    prefix = name.split("-")[0]

    if prefix in fileid_to_desc:

        description = fileid_to_desc[prefix]
        assigned_class = assign_class(description)

        if assigned_class:

            src_path = os.path.join(audio_folder, filename)
            dst_path = os.path.join(output_folder, assigned_class, filename)

            shutil.copy(src_path, dst_path)
            class_counter[assigned_class] += 1
        else:
            unmatched_files.append(filename)
    else:
        unmatched_files.append(filename)

print("\n✅ Grouping Completed.\n")

print("📊 Class Distribution:")
for cls in classes:
    print(f"{cls}: {class_counter[cls]} files")

print(f"\n⚠ Unmatched files: {len(unmatched_files)}")