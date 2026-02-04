import os
import pandas as pd
import numpy as np
from file_utils import get_word_list
from word_comparisons import check_equality
from create_text_and_voice import create_sentence_from_word, create_voice_from_text
from llama_cpp import Llama
from ollama_utils import Llama_params
from ollama_start import start_ollama

def run_test(
        language_1: str,
        language_2: str,
        no_words: int | None = None,
        llama_params: Llama_params | None = None,
        hide_used_word_for_n_words: int = 10,
        probability_for_sentence_creation: float = 0.1,
        use_voice: bool = False,
        hide_correctly_translated_words: bool = False
):  
        if llama_params is not None and len(llama_params.url) > 0:
            # check if a server under url is running
            start_ollama(llama_params.url)
        # load correct word list from folder word_lists
        selected_word_list = get_word_list(language_1, language_2)
        words = pd.read_csv(selected_word_list).squeeze()

        # shuffle words randomly
        words = words.sample(frac=1).reset_index(drop=True)
        if no_words is not None:
            words = words[:no_words]
        print(f"Running test between {language_1} and {language_2} with {len(words)} words.")
        continue_test = True
        last_used_words_indices = []

        words_to_sample_from = words.copy()
        while continue_test:
            word_language_1, word_language_2, word_index = sample_word(
                words_to_sample_from,
                language_1,
                language_2,
                probability_for_sentence_creation,
                llama_params
            )
            last_used_words_indices.append(word_index)
            last_used_words_indices = last_used_words_indices[-hide_used_word_for_n_words:]
            
            if word_language_1 is None or word_language_2 is None:
                print("No more words available for testing.")
                break

            print(f"\n{language_1}: {word_language_1}")
            if use_voice and language_1 != os.getenv("PRIMARY_LANGUAGE", "german"):
                create_voice_from_text(word_language_1, language=language_1)

            user_input = input(f"Enter the {language_2} translation: ").strip()
            
            if check_equality(user_input, word_language_2, llama_params=llama_params):
                print("✓ Correct!")
                if hide_correctly_translated_words:
                    words = words.loc[words.index.difference([word_index])]
            else:
                print(f"✗ Incorrect. The correct answer is: {word_language_2}")

            words_to_sample_from = words.loc[words.index.difference(last_used_words_indices)]

            if use_voice and language_2 != os.getenv("PRIMARY_LANGUAGE", "german"):
                create_voice_from_text(word_language_2, language=language_2)


def sample_word(
    words: pd.Series,
    language_1: str,
    language_2: str,
    probability_for_sentence_creation: float,
    llama_params: Llama_params | None = None,
) -> tuple[str, str, int]:
    """Sample a word from the given word list.
    
    Parameters:
    - words: The word list as a pandas Series.
    - language_1: The first language (e.g., "german").
    - language_2: The second language (e.g., "english").
    - probability_for_sentence_creation: Probability of creating a sentence using the word.
    - llama_params: Parameters for Llama model usage.

    Returns:
    - A tuple containing the word in language 1, the word in language 2, and the index of the word in the original list.
    """
    if words.shape[0] == 0:
        return None, None, None
    
    word = words.sample(n=1)
    word_index = word.index[0]
    
    word_language_1 = word[language_1.capitalize()].values[0]
    word_language_2 = word[language_2.capitalize()].values[0]
    num_words_in_word_language_1 = len(str(word_language_1).split())
    a = np.random.rand()
    if num_words_in_word_language_1 < 3 and a < probability_for_sentence_creation and llama_params is not None:
            word_language_1, word_language_2 = create_sentence_from_word(word_language_1, language_1, language_2, llama_params=llama_params)

    return word_language_1, word_language_2, word_index