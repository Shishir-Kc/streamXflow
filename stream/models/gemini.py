from google import genai
from decouple import config
client = genai.Client(api_key = config('GOOGLE_API_KEY'))

def gemini_chat(message:str):
    response = client.models.generate_content(
    model="gemini-3-flash-preview",
    contents=f"{message}",
    )
 
    return response.text
