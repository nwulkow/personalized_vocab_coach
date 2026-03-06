from ollama_utils import Llama_params
from llama_cpp import Llama
from create_text_and_voice import create_next_word_candidates

llm = Llama(model_path="/Users/niklaswulkow/ResearchEngineering/LLama/gemma-3-27B-it-QAT-Q4_0.gguf", n_gpu_layers=-1)
params = Llama_params(use_cpp=True, llama_llm=llm)


first_word = input("Enter the first word of the sentence: ").strip()
previous_words = [first_word]
while True:


    candidates = create_next_word_candidates(previous_words, language_1="french", llama_params=params, num_candidates=8, remark="The topic should be spicy!")
    print("Next word candidates:")
    for candidate, translation in candidates:
        print(f"{candidate} (translation: {translation})")

    next_word = input("Enter the next word (or 'exit' to finish): ").strip()
    if next_word.lower() == "exit":
        break

    previous_words.append(next_word)



    