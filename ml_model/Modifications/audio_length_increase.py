import librosa
import soundfile as sf
import numpy as np

# ==========================
# CONFIG
# ==========================
INPUT_FILE = r"C:\My\RIT\S8\Project\Dataset\Audio\Mosquito_3000\Ae. aegypti\Ae. aegypti_00000.wav"
OUTPUT_FILE = r"C:\My\RIT\S8\Project\Modifications\Mosquito\Ae. aegypti\output_5s_Ae. aegypti_00000.wav"

TARGET_DURATION = 5.0          # seconds
BREAK_DURATION = 0.1           # silence between repeats (seconds)

# ==========================
# LOAD AUDIO
# ==========================
audio, sr = librosa.load(INPUT_FILE, sr=None, mono=True)

print("Sample Rate:", sr)
print("Original Duration:", len(audio)/sr)

# ==========================
# CREATE SILENCE BREAK
# ==========================
break_samples = int(BREAK_DURATION * sr)
silence = np.zeros(break_samples)

# ==========================
# REPEAT UNTIL 5 SECONDS
# ==========================
target_samples = int(TARGET_DURATION * sr)
output_audio = np.array([])

while len(output_audio) < target_samples:
    output_audio = np.concatenate((output_audio, audio, silence))

# Trim to exact 5 seconds
output_audio = output_audio[:target_samples]

# ==========================
# SAVE FILE
# ==========================
sf.write(OUTPUT_FILE, output_audio, sr)

print("5-second file created successfully.")
print("Final Duration:", len(output_audio)/sr)