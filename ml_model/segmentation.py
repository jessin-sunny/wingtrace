import os
import librosa
import soundfile as sf
import numpy as np

# ===== PATHS =====
INPUT_PATH = r"C:\My\RIT\S8\Project\Dataset\Audio\Pest 2.0"
OUTPUT_PATH = r"C:\My\RIT\S8\Project\Dataset\Audio\Pest_2.0_Segments"

# ===== PARAMETERS =====
SR = 22050
WINDOW_SIZE = 2       # seconds
STRIDE = 1            # seconds (50% overlap)

def segment_audio():
    window_samples = int(WINDOW_SIZE * SR)
    stride_samples = int(STRIDE * SR)

    for species in os.listdir(INPUT_PATH):
        species_input_path = os.path.join(INPUT_PATH, species)
        species_output_path = os.path.join(OUTPUT_PATH, species)

        if not os.path.isdir(species_input_path):
            continue

        os.makedirs(species_output_path, exist_ok=True)

        for file in os.listdir(species_input_path):
            if not file.endswith(".wav"):
                continue

            file_path = os.path.join(species_input_path, file)

            try:
                audio, sr = librosa.load(file_path, sr=SR, mono=True)

                segment_count = 0

                for start in range(0, len(audio), stride_samples):
                    end = start + window_samples
                    segment = audio[start:end]

                    # Pad if last segment is shorter
                    if len(segment) < window_samples:
                        pad_length = window_samples - len(segment)
                        segment = np.pad(segment, (0, pad_length), mode='constant')

                    segment_filename = f"{file[:-4]}_seg{segment_count}.wav"
                    segment_path = os.path.join(species_output_path, segment_filename)

                    sf.write(segment_path, segment, SR)
                    segment_count += 1

                    if end >= len(audio):
                        break

                print(f"Processed {file} → {segment_count} segments")

            except Exception as e:
                print(f"Error processing {file}: {e}")

if __name__ == "__main__":
    segment_audio()