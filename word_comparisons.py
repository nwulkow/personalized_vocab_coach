import ollama


def check_equality(word1:str, word2:str, ollama_model_id:str | None = None) -> bool:
    """Check if two words are exactly the same.

    Args:
        word1 (str): The first word to compare.
        word2 (str): The second word to compare.

    Returns:
        bool: True if the words are identical, False otherwise.
    """
    if word1.lower() == word2.lower():
        return True
    
    else:
        if not ollama_model_id:
            return False
        response = ollama.chat(
            model=ollama_model_id,
            messages=[{"role": "user", "content": f"Do the expressions '{word1}' and '{word2}' mean the same thing? Answer only (!) with 'yes' or 'no'."}],
        )
        response = response['message']['content'].strip().lower()
        if "no" in response:
            return False
        elif "yes" in response:
            return True
        else:
            raise ValueError(f"Unexpected response from model: {response}")