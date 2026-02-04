import ollama
from ollama_utils import Llama_params, respond_to_prompt


def check_equality(word1:str, word2:str, llama_params: Llama_params | None = None) -> bool:
    """Check if two words are exactly the same.

    Args:
        word1 (str): The first word to compare.
        word2 (str): The second word to compare.
        llama_params (Llama_params, optional): Parameters for the Llama model. If provided, it will be used to check the equality of the words using a language model. Defaults to None.

    Returns:
        bool: True if the words are identical, False otherwise.
    """
    if word1.lower() == word2.lower():
        return True
    
    else:
        if not llama_params:
            return False
        
        prompt = f"""
            Classify the relationship between the following expressions.

            Expression A: "{word1}"
            Expression B: "{word2}"

            Label:
            - SAME → meanings are equivalent in everyday usage
            - DIFFERENT → meanings are not equivalent in everyday usage

            It is important that they must mean the same thing, not just be similar. But do not consider minor differences such as plural/singular, verb conjugations, or small spelling mistakes. Focus on the core meaning of the words. Do not be too stringent.

            Answer with ONLY: SAME or DIFFERENT
            """

        response = respond_to_prompt(
            prompt,
            llama_params,
            temperature=0.01,
            max_tokens=100,
            #stop_phrases=["SAME", "DIFFERENT", "same", "different"]
        )
        response = response.strip().lower()
        if "different" in response:
            return False
        elif "same" in response:
            return True
        else:
            print(f"Warning: Unexpected response from model: {response}")
            return False
