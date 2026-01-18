from fastapi import FastAPI, UploadFile, File, HTTPException ,Response
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from models.krypton import Krypton
from models.gpt import Gpt
from groq import AsyncGroq
from models.gemini import gemini_chat
from decouple import config
import os 
from pathlib import Path
krypton = Krypton()
gpt = Gpt()



class Chat(BaseModel):
    chat:str


app = FastAPI()



@app.post('/v1/chat/krypton/')
def chat_ai_krypton(user:Chat):
    respsone = krypton.ai_krypton(message=user.chat)
    print(respsone)
    return {
            'reply':respsone
        }



@app.post('/v1/chat/krypton/agent/')
def chat_agent_krypton(user:Chat):
    respsone = krypton.agent_krypton(message=user.chat)

    return {
            'reply':respsone
        }


@app.post('/v1/chat/gpt/')
def chat_gpt(user:Chat):
    respsone = gpt.ai_gpt(message=user.chat)
    
    return {
            'reply':respsone
        }


@app.post('/v1/chat/gemini/3/flash/preview/')
def chat_ai_gemini_3(user:Chat):
    respsone = gemini_chat(message=user.chat)
    
    return {
            'reply':respsone
        }



@app.post("/v1/transcribe/")
async def transcribe_audio(file: UploadFile = File(...)):
    client = AsyncGroq(api_key=config('GROQ_API_KEY'))
    try:
        # 1. Read the file bytes directly into memory
        audio_data = await file.read()
        
        # 2. Get the filename
        filename = file.filename
        
        # 3. Send to Groq for Transcription
        # We pass a tuple: (filename, bytes)
        transcription = await client.audio.transcriptions.create(
            file=(filename, audio_data),
            model="whisper-large-v3",
            response_format="verbose_json",  # or "text", "vtt", "srt"
            language="en"            # optional
        )

        # 4. Return the transcription text to your Dart frontend
        return {"text": transcription.text}

    except Exception as e:
        print(f"Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        # Ensure the file is closed
        await file.close()


@app.post("/v1/live/conv/")
async def transcribe_audio(file: UploadFile = File(...)):
    client = AsyncGroq(api_key=config('GROQ_API_KEY'))
    try:

        audio_data = await file.read()
        
     
        filename = file.filename
        

        transcription = await client.audio.transcriptions.create(
            file=(filename, audio_data),
            model="whisper-large-v3",
            response_format="verbose_json",  
            language="en"            
        )
        ai_response = gpt.ai_gpt(message=transcription.text,outputlength="use less words to reply with max 200 words no more then that ")
        response = await client.audio.speech.create(
        model="canopylabs/orpheus-v1-english",
        voice="autumn",
        response_format="wav",
        input=ai_response,
        )

        return StreamingResponse(response.iter_bytes(), media_type="audio/wav")



    except Exception as e:
        print(f"Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:

        await file.close()



