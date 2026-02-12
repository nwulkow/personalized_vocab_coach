import os
import pandas as pd
import numpy as np
from file_utils import get_word_list
from word_comparisons import check_equality
from create_text_and_voice import create_sentence_from_word, create_voice_from_text
from llama_cpp import Llama
from ollama_utils import Llama_params, respond_to_prompt
from ollama_start import start_ollama

def run_test(
        language_1: str,
        language_2: str,
        no_words: int | None = None,
        llama_params: Llama_params | None = None,
        hide_used_word_for_n_words: int = 10,
        probability_for_sentence_creation: float = 0.1,
        use_voice: bool = False,
        hide_correctly_translated_words: bool = False,
        description_for_word_filtering: str | None = None,
        max_num_words_in_created_sentence: int = 10,
        language_level_for_created_sentence: str = "C1",
        be_stringent: bool = False,
        word_batch_size: int = 20
):
    """Run a vocabulary test between two languages. 
    Parameters:
    - language_1: The first language (e.g., "german").
    - language_2: The second language (e.g., "english").
    - no_words: Number of words to test. If None, use all words in the word list.
    - llama_params: Parameters for Llama model usage.
    - hide_used_word_for_n_words: Number of recently used words to hide from the test.
    - probability_for_sentence_creation: Probability of creating a sentence using the word.
    - use_voice: Whether to use voice synthesis for the words.
    - hide_correctly_translated_words: Whether to hide words that were translated correctly.
    - description_for_word_filtering: Description to filter words from the word list.
    - max_num_words_in_created_sentence: Maximum number of words in the created sentence.
    - language_level_for_created_sentence: Language level for the created sentence (e.g., "C1").
    - be_stringent: Whether to be stringent in checking the user's translation (e.g., by using a Llama model to check for correctness).
    - word_batch_size: The number of words to include in each batch when filtering words by description.
    """
    
    if llama_params is not None and len(llama_params.url) > 0:
        # check if a server under url is running
        start_ollama(llama_params.url)
    # load correct word list from folder word_lists
    selected_word_list = get_word_list(language_1, language_2)
    words = pd.read_csv(selected_word_list).squeeze()

    if description_for_word_filtering is not None and description_for_word_filtering != "" and llama_params is not None:
        words_filtered = filter_word_list_by_description(words, language_1, description_for_word_filtering, llama_params, word_batch_size=word_batch_size)
        if words_filtered.shape[0] == 0:
            print("No words found matching the description. Using the full word list.")
        else:
            words = words_filtered
            print(f"{words.shape[0]} words found matching the description. Using the filtered word list.")

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
            llama_params,
            max_num_words_in_created_sentence,
            language_level_for_created_sentence
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
        
        if check_equality(user_input, word_language_2, llama_params=llama_params, be_stringent=be_stringent):
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
    max_num_words_in_created_sentence: int = 10,
    language_level_for_created_sentence: str = "C1"
) -> tuple[str, str, int]:
    """Sample a word from the given word list.
    
    Parameters:
    - words: The word list as a pandas Series.
    - language_1: The first language (e.g., "german").
    - language_2: The second language (e.g., "english").
    - probability_for_sentence_creation: Probability of creating a sentence using the word.
    - llama_params: Parameters for Llama model usage.
    - max_num_words_in_created_sentence: Maximum number of words in the created sentence.
    - language_level_for_created_sentence: Language level for the created sentence (e.g., "C1").

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
            word_language_1, word_language_2 = create_sentence_from_word(
                word_language_1,
                language_1,
                language_2,
                llama_params=llama_params,
                max_num_words=max_num_words_in_created_sentence,
                language_level=language_level_for_created_sentence
    )

    return word_language_1, word_language_2, word_index



def filter_word_list_by_description(
    words: pd.Series,
    language_1: str,
    description: str,
    llama_params: Llama_params,
    word_batch_size: int = 20,
) -> pd.Series:
    """Choose a subset of words from the given word list based on a description.

    Parameters:
    - words: The word list as a pandas Series.
    - language_1: The language of the words in the list (e.g., "german").
    - description: A description of the word to choose.
    - llama_params: Parameters for Llama model usage.
    - word_batch_size: The number of words to include in each batch when sending to the Llama model.

    Returns:
    - A tuple containing the word in language 1, the word in language 2, and the index of the word in the original list.
    """
    if words.shape[0] == 0:
        return None
    
    words_list_full = words[language_1.capitalize()].astype(str).tolist()
    response_words_collected = []

    for i in range(0, len(words_list_full), word_batch_size):
        words_batch = words_list_full[i:i + word_batch_size]
        words_batch_str = ";".join(words_batch)

        prompt = f"""Return only the words that match the description, separated by semicolons.
            Do not return any explanations or additional text.
            Description: {description}
            Words:
            {words_batch_str}
            """

        response_words_batch = respond_to_prompt(
            prompt,
            llama_params,
            temperature=0.1,
        )

        parsed_words = [w.strip() for w in response_words_batch.strip().split(";") if w.strip()]
        parsed_words = [w for w in parsed_words if w in words_batch]
        response_words_collected.extend(parsed_words)

    # remove duplicates while preserving order
    response_words = list(dict.fromkeys(response_words_collected))

    words_filtered = words[words[language_1.capitalize()].isin(response_words)]

    return words_filtered


