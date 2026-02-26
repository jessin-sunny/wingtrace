import os
import librosa
import warnings

warnings.filterwarnings("ignore")  # hides future warnings

DATASET_PATH = r"C:\My\RIT\S8\Project\Dataset\Audio\Pest 2.0"

def get_audio_stats(dataset_path):
    total_dataset_duration = 0
    total_files = 0

    print("\n===== DATASET STATISTICS =====\n")

    for species in os.listdir(dataset_path):
        species_path = os.path.join(dataset_path, species)

        if os.path.isdir(species_path):
            file_count = 0
            total_duration = 0

            for file in os.listdir(species_path):
                if file.endswith(".wav"):
                    file_path = os.path.join(species_path, file)

                    try:
                        duration = librosa.get_duration(path=file_path)
                        total_duration += duration
                        file_count += 1
                    except:
                        pass

            total_files += file_count
            total_dataset_duration += total_duration

            print(f"Species: {species}")
            print(f"  Number of WAV files: {file_count}")
            print(f"  Total Duration: {total_duration:.2f} sec "
                  f"({total_duration/60:.2f} min)\n")

    print("===== OVERALL DATASET =====")
    print(f"Total WAV Files: {total_files}")
    print(f"Total Duration: {total_dataset_duration:.2f} sec "
          f"({total_dataset_duration/60:.2f} min)")
    print("\n=============================")

if __name__ == "__main__":
    get_audio_stats(DATASET_PATH)