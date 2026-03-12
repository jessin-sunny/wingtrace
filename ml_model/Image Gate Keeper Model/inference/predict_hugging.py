from gradio_client import Client, handle_file

# Connects to your specific 16GB server
client = Client("wingtrace/wingmodel")

# Send the local image to the server
print("Sending image to server...")
result = client.predict(
    image=handle_file(r"C:\My\RIT\S8\Project\Dataset\Image\Gate - Unseen\mosquito\1280px-Mosquito_Tasmania.jpg"), # <-- YOUR LOCAL FILE PATH
    api_name="/predict_bug"
)

# Print the AI's response
print("\n✅ SERVER RESPONSE:")
print(result)