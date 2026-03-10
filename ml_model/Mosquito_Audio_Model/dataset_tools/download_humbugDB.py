import requests
from tqdm import tqdm
import os

# Zenodo record ID for HumBugDB
record_id = "4904800"

api_url = f"https://zenodo.org/api/records/{record_id}"

response = requests.get(api_url)
data = response.json()

# Folder to save dataset
download_folder = "C:\My\RIT\S8\Project\Dataset\Audio\HumBugDB_dataset"
os.makedirs(download_folder, exist_ok=True)

files = data["files"]

print(f"Found {len(files)} files")

for file in files:
    file_url = file["links"]["self"]
    filename = file["key"]

    filepath = os.path.join(download_folder, filename)

    print(f"\nDownloading: {filename}")

    r = requests.get(file_url, stream=True)

    total = int(r.headers.get("content-length", 0))

    with open(filepath, "wb") as f, tqdm(
        desc=filename,
        total=total,
        unit="B",
        unit_scale=True,
        unit_divisor=1024,
    ) as bar:
        for chunk in r.iter_content(chunk_size=1024):
            if chunk:
                f.write(chunk)
                bar.update(len(chunk))

print("\nDownload completed!")