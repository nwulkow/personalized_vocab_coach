from googletrans import Translator
from ollama_utils import Llama_params, respond_to_prompt

from file_utils import add_word_pair_to_word_list

google_trans_language_to_file_language_dict = {
    "de": "german",
    "en": "english",
    "fr": "french",
    "es": "spanish",
    "it": "italian",
    "pt": "portuguese",
    "ru": "russian",
    "zh-cn": "chinese_simplified",
    "ja": "japanese",
    "ko": "korean",
}


async def translate_text(text: str, src_language: str, dest_language: str, add_to_word_list: bool = False, speak_translated: bool = False) -> str:
    async with Translator() as translator:
        result = await translator.translate(text, src=src_language, dest=dest_language)
        # return error message if translation failed
        if result.text is None:
            return "Translation failed."
        if speak_translated:
            from create_text_and_voice import create_voice_from_text
            create_voice_from_text(result.text, language=dest_language)
        if add_to_word_list:
            language_1 = google_trans_language_to_file_language_dict.get(src_language)
            language_2 = google_trans_language_to_file_language_dict.get(dest_language)
            add_word_pair_to_word_list(text, result.text, language_1, language_2)
        return result.text



def show_multiple_translations(word: str, src_language: str, dest_language: str, LLama_params: Llama_params, max_num_translations: int = 5, google_translation: str | None = None) -> list[str]:
    """Show multiple translations for a given word using a Llama model.
    Parameters:
    - word: The word to translate.
    - src_language: The source language (e.g., "english").
    - dest_language: The destination language (e.g., "german").
    - LLama_params: Parameters for the Llama model to use for generating translations.
    - max_num_translations: The maximum number of translations to return.
    - google_translation: An optional translation from Google Translate to include as the first translation.

    Returns:
    - A list of translations for the given word.
    """
    
    prompt = f"""
        Provide a list of at most {max_num_translations} different translations for the word "{word}" from {src_language} to {dest_language}. 
        The translations should be common and widely used. 
        If there are not {max_num_translations} different translations, provide as many as possible.
        Return the translations in a semicolon-separated format without any additional text.
    """
    if google_translation is not None:
        prompt += f" The Google Translate translation for this word is: {google_translation}. Use it as the first word you return."

    response = respond_to_prompt(
        prompt,
        LLama_params,
        temperature=0.1,
        max_tokens=100,
    )
    translations = [t.strip() for t in response.split(";") if t.strip()]
    return translations
    