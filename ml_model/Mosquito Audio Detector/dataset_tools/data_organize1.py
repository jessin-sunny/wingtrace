import os
import pandas as pd
import shutil

# -------------------------------------------------
# PATHS
# -------------------------------------------------
csv_path = r"C:\Users\jessi\Downloads\ESC-50-master\ESC-50-master\meta\esc50.csv"
audio_path = r"C:\Users\jessi\Downloads\ESC-50-master\ESC-50-master\audio"
output_path = r"C:\My\RIT\S8\Project\Dataset\Audio\Noise"

os.makedirs(output_path, exist_ok=True)

# -------------------------------------------------
# TARGET CATEGORIES
# -------------------------------------------------
target_categories = [
    "dog","rain","crying_baby","door_knock","helicopter",
    "rooster","sea_waves","sneezing","mouse_click","chainsaw",
    "pig","crackling_fire","clapping","keyboard_typing","siren",
    "cow","breathing","car_horn",
    "frog","chirping_birds","coughing","engine",
    "cat","water_drops","footsteps","washing_machine","train",
    "hen","wind","laughing","vacuum_cleaner","church_bells",
    "pouring_water","airplane",
    "sheep","snoring","fireworks",
    "crow","thunderstorm","glass_breaking","hand_saw"
]

# normalize category names
target_categories = [c.lower() for c in target_categories]

# -------------------------------------------------
# LOAD CSV
# -------------------------------------------------
df = pd.read_csv(csv_path)

# normalize CSV category column
df["category"] = df["category"].str.lower().str.replace(" ", "_").str.replace(",", "")

# -------------------------------------------------
# FILTER
# -------------------------------------------------
filtered = df[df["category"].isin(target_categories)]

print("Total filtered samples:", len(filtered))

# -------------------------------------------------
# COPY FILES
# -------------------------------------------------
copied = 0
missing = 0

for _, row in filtered.iterrows():
    filename = row["filename"]

    src = os.path.join(audio_path, filename)
    dst = os.path.join(output_path, filename)

    if os.path.exists(src):
        shutil.copy(src, dst)
        copied += 1
    else:
        missing += 1

print("Copied files:", copied)
print("Missing files:", missing)
print("Finished organizing dataset.")