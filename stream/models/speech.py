
import os
from groq import Groq
from pathlib import Path
from decouple import config

client = Groq(api_key=config('GROQ_API_KEY'))
speech_file_path = Path(__file__).parent / "speech.wav"
response = client.audio.speech.create(
  model="canopylabs/orpheus-v1-english",
  voice="autumn",
  response_format="wav",
  input="hello i am your daily host suzennnn !  ! ",
)
response.write_to_file(speech_file_path)
      