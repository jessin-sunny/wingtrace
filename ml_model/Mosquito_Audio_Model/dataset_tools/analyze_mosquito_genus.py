import pandas as pd

df = pd.read_csv(r"C:\My\RIT\S8\Project\WingTrace\ml_model\Mosquito Audio Model\neurips_2021_zenodo_0_0_1.csv")

# filter only mosquito
df = df[df["sound_type"] == "mosquito"]

# create genus column
def get_genus(s):
    if pd.isna(s):
        return None
    s = s.lower()
    if s.startswith("ae"):
        return "aedes"
    if s.startswith("an"):
        return "anopheles"
    if s.startswith("culex"):
        return "culex"
    return None

df["genus"] = df["species"].apply(get_genus)

# compute stats
summary = df.groupby("genus")["length"].agg([
    "count",
    "sum",
    "mean",
    "median"
])

print(summary)