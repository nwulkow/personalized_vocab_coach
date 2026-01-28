import asyncio
import pandas as pd
from translator_utils import translate_text


def test_translate_text():
        translated_fr = asyncio.run(translate_text("Weit", "de", "fr"))
        assert translated_fr == "Loin"

        translated_de = asyncio.run(translate_text("House", "en", "de"))
        assert translated_de == "Haus"

        translated_es = asyncio.run(translate_text("House", "de", "es"))
        assert translated_es == "Casa"

def test_add_to_word_list():
    asyncio.run(translate_text("Nose", "en", "de", add_to_word_list=True))

    asyncio.run(translate_text("Haus", "de", "en", add_to_word_list=True))

    asyncio.run(translate_text("pire", "fr", "de", add_to_word_list=True))

    asyncio.run(translate_text("Weit", "de", "fr", add_to_word_list=True))

    asyncio.run(translate_text("Test", "de", "es", add_to_word_list=True))
    # load word_lists/german_english.csv and check if "Haus, House" is in there
    word_list_path = "word_lists/german_english.csv"
    words = pd.read_csv(word_list_path).squeeze()
    assert ["Haus", "House"] in words.values

if __name__ == "__main__":
    test_translate_text()

    test_add_to_word_list()