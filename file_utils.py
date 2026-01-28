import glob
import pandas as pd

def get_word_list(language_1, language_2) -> str:
    """
    Get the path to the word list file for the given language pair.

    Parameters:
    - language_1: The first language (e.g., "german").
    - language_2: The second language (e.g., "english").

    Returns:
    - The path to the word list file.
    
    Raises:
    - ValueError: If no word list is found for the given language pair.
    """

    word_lists = glob.glob("word_lists/*.csv")
    selected_word_list = None
    for word_list in word_lists:
        if f"{language_1.lower()}_{language_2.lower()}.csv" in word_list:
            selected_word_list = word_list
            break
        elif f"{language_2.lower()}_{language_1.lower()}.csv" in word_list:
            selected_word_list = word_list
            break
    if selected_word_list is None:
            raise ValueError(f"No word list found for languages: {language_1}, {language_2}")
    return selected_word_list


def add_word_pair_to_word_list(word_language_1: str, word_language_2: str, language_1: str, language_2: str) -> None:
    """
    Add a new word pair to the appropriate word list file.

    Parameters:
    - word_language_1: The word in the first language.
    - word_language_2: The word in the second language.
    - language_1: The first language (e.g., "german").
    - language_2: The second language (e.g., "english").
    """

    word_list_path = get_word_list(language_1, language_2)
    new_row = pd.DataFrame({language_1.capitalize(): [word_language_1.strip()], language_2.capitalize(): [word_language_2.strip()]})
    
    words: pd.DataFrame = pd.read_csv(word_list_path).squeeze()
    if not ((words[language_1.capitalize()] == word_language_1.strip()).any() and (words[language_2.capitalize()] == word_language_2.strip()).any()):
        words = pd.concat([words, new_row], ignore_index=True)
        words.to_csv(word_list_path, index=False)