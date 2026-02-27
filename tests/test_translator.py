import asyncio
import pandas as pd
from llama_cpp import Llama
from ollama_utils import Llama_params
from translator_utils import translate_text, show_multiple_translations


def test_translate_text():
        translated_fr = asyncio.run(translate_text("Weit", "de", "fr"))
        assert translated_fr == "Loin"

        translated_de = asyncio.run(translate_text("House", "en", "de"))
        assert translated_de == "Haus"

        translated_es = asyncio.run(translate_text("House", "de", "es"))
        assert translated_es == "Casa"

def test_add_to_word_list():

    asyncio.run(translate_text("Test", "de", "es", add_to_word_list=True))
    # load word_lists/german_english.csv and check if "Haus, House" is in there
    # word_list_path = "word_lists/german_english.csv"
    #words = pd.read_csv(word_list_path).squeeze()
    # assert ["Haus", "House"] in words.iloc[:, :2].values


def test_show_multiple_translations():
    llm = Llama(model_path="/Users/niklaswulkow/ResearchEngineering/LLama/gemma-3-27B-it-QAT-Q4_0.gguf", n_gpu_layers=-1)
    params = Llama_params(use_cpp=True, llama_llm=llm)
    translations = show_multiple_translations("rechazar", "spanish", "german", params, max_num_translations=3, google_translation="Abfall")
    assert isinstance(translations, list)
    assert len(translations) <= 3
    print(translations)

if __name__ == "__main__":
    test_translate_text()

    test_add_to_word_list()

    test_show_multiple_translations()