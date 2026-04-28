from fastapi import FastAPI, UploadFile, File, HTTPException, Response
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from io import BytesIO
from models.krypton import Krypton
from models.gpt import Gpt
from models.gem_tts import generate_tts
from decouple import config
from models.openai_gpt import (
    generate_response,
    generate_speech,
    client as openai_client,
)
import os

from pathlib import Path

krypton = Krypton()
gpt = Gpt()


class Chat(BaseModel):
    chat: str


app = FastAPI()


@app.post("/v1/chat/krypton/")
def chat_ai_krypton(user: Chat):
    respsone = krypton.ai_krypton(message=user.chat)
    print(respsone)
    return {"reply": respsone}


@app.post("/v1/chat/krypton/agent/")
def chat_agent_krypton(user: Chat):
    respsone = krypton.agent_krypton(message=user.chat)

    return {"reply": respsone}


@app.post("/v1/chat/gpt/")
def chat_gpt(user: Chat):
    respsone = generate_response(prompt=user.chat)

    return {"reply": respsone}


@app.post("/v1/chat/gemini/3/flash/preview/")
def chat_ai_gemini_3(user: Chat):
    respsone = gemini_chat(message=user.chat)

    return {"reply": respsone}


@app.post("/v1/transcribe/")
async def transcribe_audio(file: UploadFile = File(...)):
    try:
        audio_data = await file.read()
        filename = file.filename

        transcription = openai_client.audio.transcriptions.create(
            file=(filename, audio_data), model="gpt-4o-mini-transcribe"
        )

        return {"text": transcription.text}

    except Exception as e:
        print(f"Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        await file.close()


@app.post("/v1/live/conv/")
async def live_conversation(file: UploadFile = File(...)):
    try:
        audio_data = await file.read()
        filename = file.filename

        transcription = openai_client.audio.transcriptions.create(
            file=(filename, audio_data), model="gpt-4o-mini-transcribe"
        )
        print("AI TRANSCRIPTION (GTP 4o gpt-4o-mini-transcribe ) : ",transcription)
        ai_response = generate_response(transcription.text)
        print(
            "AI Response (GTP gpt-4o-mini ) :  ",ai_response
        )
        audio_data = generate_speech(ai_response, "output_speech.mp3")

        return StreamingResponse(BytesIO(audio_data), media_type="audio/mpeg")

    except Exception as e:
        print(f"Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        await file.close()


# @app.post("/api/v1/image/to/text/")
# async def read_image_text(image:UploadFile=File(...)):

#     image_bytes = await image.read()
#     img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
#     img_array = np.array(img)
#     results = reader.readtext(img_array)

#     texts = []
#     for _, text, conf in results:
#         texts.append({
#             "text": text,
#             "confidence": float(conf)
#         })

#     return {
#         "filename": image.filename,
#         "results": texts
#     }
