import ollama
import pyttsx3

def create_sentence_from_word(
    word: str,
    language_1: str,
    language_2: str,
    model_id: str | None = None
) -> tuple[str, str]:
    
    prompt = (
        f"Create a simple sentence (up to 10 words) in {language_1} using the word '{word.split(',')[0].strip()}' "
        f"and provide its translation in {language_2}. "
        f"Respond in the format: <sentence in {language_1}>; <sentence in {language_2}>."
    )
    response = ollama.chat(
            model=model_id,
            messages=[{"role": "user", "content": prompt}],
        )
    parts = response.split(";")
    if len(parts) < 2:
        raise ValueError("The generated sentence does not contain both parts.")
    sentence_language_1 = parts[0].strip()
    sentence_language_2 = parts[1].strip()
    return sentence_language_1, sentence_language_2


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