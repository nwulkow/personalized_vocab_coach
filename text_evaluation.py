from llm_utils.llm_api_utils import respond_with_gemini
from file_utils import get_word_list_file_name
import pandas as pd
from typing import Literal
import os


def find_mistakes(text_from_user: str, level: Literal["Basic", "Intermediate", "Advanced"] = "Intermediate") -> str:
    prompt = f"""
        The user provided the following translation: "{text_from_user}".
        Please check if there are any mistakes and explain them briefly, but consicse.
        If there are no mistakes, only say "No mistakes found."
    """
    if level == "Basic":
        prompt += " Focus only on very basic mistakes that a beginner learner of the language would make, such as incorrect word order, missing articles, or incorrect verb conjugations. Do not point out more subtle mistakes that are not crucial for basic communication."
    elif level == "Advanced":
        prompt += " Be very thorough in checking for mistakes, including subtle ones that may not be crucial for basic communication but are important for advanced proficiency. Pay attention to nuances, idiomatic expressions, and stylistic issues."
    else:
        prompt += " Check for common mistakes that learners of the language make, but do not be overly strict. Focus on mistakes that would hinder clear communication, but do not point out very minor issues that do not affect the overall meaning."
    response = respond_with_gemini(prompt)
    return response.strip()


def run_text_evaluation_loop(language: str, no_words_per_task: int = 1, level: Literal["Basic", "Intermediate", "Advanced"] = "Intermediate") -> None:
    selected_word_list = get_word_list_file_name(os.getenv("PRIMARY_LANGUAGE", "german"), language)
    words = pd.read_csv(selected_word_list)[language.capitalize()].dropna().unique()
    while True:
        words_to_translate = pd.Series(words).sample(no_words_per_task).tolist()
        print(f"Please write a text containing the following word in {language}: {', '.join(words_to_translate)}")
        user_input = input("Your text: ")
        mistakes = find_mistakes(user_input, level=level)
        print(f"Feedback on your translation: {mistakes}")
    
    
    
if __name__ == "__main__":
    run_text_evaluation_loop(language="english", no_words_per_task=2, level="Advanced")