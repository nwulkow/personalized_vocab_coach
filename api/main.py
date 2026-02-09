from fastapi import FastAPI
from pydantic import BaseModel
import asyncio
import pandas as pd
from ollama_utils import llama_params_from_dict
from translator_utils import translate_text
from word_test_runner import sample_word
    
app = FastAPI(docs_url="/swagger")

@app.get("/")
def root():
    return {"status": "running"}

@app.post("/translate")
def translate(text: str, src_language: str, dest_language: str, speak_translated: bool):
    
    translated_text = asyncio.run(translate_text(text, src_language, dest_language, speak_translated=speak_translated))
    return {"translated_text": translated_text}


@app.post("/create_word")
def create_word(
    words_language_1: list[str],
    words_language_2: list[str],
    language_1: str,
    language_2: str,
    probability_for_sentence_creation: float,
    llama_params_dict: dict | None = None,
    max_num_words_in_created_sentence: int = 10,
    language_level_for_created_sentence: str = "C1"
):
    
    words = pd.DataFrame({language_1.capitalize(): words_language_1, language_2.capitalize(): words_language_2})

    if llama_params_dict is not None:
        llama_params = llama_params_from_dict(llama_params_dict)
    else:
        llama_params = None

    word = sample_word(
        words,
        language_1,
        language_2,
        probability_for_sentence_creation,
        llama_params,
        max_num_words_in_created_sentence,
        language_level_for_created_sentence
    )

    return {"word": word}

