import asyncio
import ollama
import pyttsx3
from ollama_utils import respond_to_prompt, Llama_params
from translator_utils import translate_text

def create_sentence_from_word(
    word: str,
    language_1: str,
    language_2: str,
    llama_params: Llama_params,
    temperature: float = 0.7,
    max_num_words: int = 10,
    language_level: str = "C1",
    remark: str | None = None
) -> tuple[str, str]:
    
    if word.startswith("to "):
        word = word[3:]

    prompt = (
        f"Create a simple sentence (up to {max_num_words} words) in {language_1} using the word '{word.split(',')[0].strip()}' "
        f"The sentences should have maximal difficulty for a language learner at the {language_level} level. "
        f"{remark if remark else ''}"
        f"Only (!) return the created sentence and nothing more!"
    )

    response_in_language_1 = respond_to_prompt(
        prompt,
        llama_params,
        temperature=temperature,
        stop_phrases=["."]
    )
    response_in_language_1 = response_in_language_1.strip().split("\n")[0].strip('"').strip("'")
    response_in_language_2 = asyncio.run(translate_text(response_in_language_1, language_1, language_2, add_to_word_list=False, speak_translated=False))

    return response_in_language_1, response_in_language_2


def create_voice_from_text(
        text: str,
        voice: str | None = None,
        language: str | None = None
):
    engine = pyttsx3.init()

    if voice is not None:
        engine.setProperty('voice', voice)

    else:
        if language is not None:
            if language == "french" or language == "fr":
                engine.setProperty('voice', "com.apple.eloquence.fr-FR.Flo")

            if language == "german" or language == "de":
                engine.setProperty('voice', "com.apple.eloquence.de-DE.Annika")

            if language == "spanish" or language == "es":
                engine.setProperty('voice', "com.apple.eloquence.es-ES.Flo")

            if language == "english" or language == "en":
                engine.setProperty('voice', "com.apple.speech.synthesis.voice.Fred")

    engine.say(text)
    engine.runAndWait()

def list_all_voices():
    engine = pyttsx3.init()
    voices = engine.getProperty('voices')
    for voice in voices:
        print(f"ID: {voice.id}")
        print(f"Name: {voice.name}")
        print(f"Languages: {voice.languages}")