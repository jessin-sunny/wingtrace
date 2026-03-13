from gradio_client import Client, handle_file

client = Client("wingtrace/audiomodel")
print("Sending audio to server...")
result = client.predict(
	audio_filepath=handle_file(r"C:\My\RIT\S8\Project\Dataset\Audio\Mosquito_3000\Ae. aegypti\Ae. aegypti_00000.wav"),
	api_name="/analyze_wingbeat",
)
print(result)