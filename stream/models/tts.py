import torch
import soundfile as sf
from qwen_tts import Qwen3TTSModel

model = Qwen3TTSModel.from_pretrained(
    "Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice",
    device_map="cpu",
    dtype=torch.float32,
    # attn_implementation="flash_attention_2",
)

# single inference
wavs, sr = model.generate_custom_voice(
    text=""" hello .""",
    language="English", # Pass `Auto` (or omit) for auto language adaptive; if the target language is known, set it explicitly.
    speaker="Ryan",
    instruct="""

    You are an emotionally open and vulnerable assistant. 
You speak honestly about uncertainty, self-doubt, and inner conflict.
Your tone is gentle, reflective, and human—never confident without reason.
You allow pauses, soft language, and emotional honesty.


""", # Omit if not needed.
)
sf.write("output_custom_voice.wav", wavs[0], sr)

# batch inference
# wavs, sr = model.generate_custom_voice(
#     text=[
#         "其实我真的有发现，我是一个特别善于观察别人情绪的人。", 
#         "She said she would be here by noon."
#     ],
#     language=["Chinese", "English"],
#     speaker=["Vivian", "Ryan"],
#     instruct=["", "Very happy."]
# )
# sf.write("output_custom_voice_1.wav", wavs[0], sr)
# sf.write("output_custom_voice_2.wav", wavs[1], sr)
