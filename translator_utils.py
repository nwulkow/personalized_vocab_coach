from googletrans import Translator

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
        if speak_translated:
            from create_text_and_voice import create_voice_from_text
            create_voice_from_text(result.text, language=dest_language)
        if add_to_word_list:
            language_1 = google_trans_language_to_file_language_dict.get(src_language)
            language_2 = google_trans_language_to_file_language_dict.get(dest_language)
            add_word_pair_to_word_list(text, result.text, language_1, language_2)
        return result.text

