import os
import wave

input_folder = r"C:\My\RIT\S8\Project\Dataset\Audio\Mosquito_3000\Ae. aegypti"

batch3_output = "aegypti_batch3.wav"
batch4_output = "aegypti_batch4_fan.wav"

step = 12
files_per_batch = 125


def combine_files(start_index, output_file):
    combined_audio = []
    params = None

    for i in range(files_per_batch):
        idx = start_index + i * step
        filename = f"Ae. aegypti_{idx:05d}.wav"
        filepath = os.path.join(input_folder, filename)

        with wave.open(filepath, 'rb') as wf:
            if params is None:
                params = wf.getparams()

                # create 0.1 second silence
                sample_rate = wf.getframerate()
                sample_width = wf.getsampwidth()
                channels = wf.getnchannels()

                silence_frames = int(0.2 * sample_rate)
                silence = b'\x00' * silence_frames * sample_width * channels

            frames = wf.readframes(wf.getnframes())
            combined_audio.append(frames)
            combined_audio.append(silence)

    with wave.open(output_file, 'wb') as out:
        out.setparams(params)

        for frames in combined_audio:
            out.writeframes(frames)

    print("Created:", output_file)


# Batch 3 (start at 1)
combine_files(1, batch3_output)

# Batch 4 (start at 1501)
combine_files(1501, batch4_output)