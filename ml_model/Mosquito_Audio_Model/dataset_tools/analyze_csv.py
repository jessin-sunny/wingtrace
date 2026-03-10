import pandas as pd

# Load CSV
csv_path = r"C:\My\RIT\S8\Project\WingTrace\ml_model\Mosquito Audio Model\neurips_2021_zenodo_0_0_1.csv"
df = pd.read_csv(csv_path)

print("\n==== BASIC INFO ====")
print(df.info())

print("\n==== FIRST 5 ROWS ====")
print(df.head())

print("\n==== COLUMN NAMES ====")
print(df.columns)

print("\n==== MISSING VALUES ====")
print(df.isnull().sum())

print("\n==== DATASET SIZE ====")
print("Rows:", df.shape[0])
print("Columns:", df.shape[1])

# If species column exists
if "species" in df.columns:
    print("\n==== SPECIES DISTRIBUTION ====")
    print(df["species"].value_counts())

# If length column exists
if "length" in df.columns:
    print("\n==== AUDIO LENGTH STATS ====")
    print(df["length"].describe())

# If sound_type exists
if "sound_type" in df.columns:
    print("\n==== SOUND TYPE DISTRIBUTION ====")
    print(df["sound_type"].value_counts())