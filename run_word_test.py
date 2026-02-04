from ollama_utils import Llama_params
from word_test_runner import run_test
from llama_cpp import Llama


llm = Llama(model_path="/Users/niklaswulkow/ResearchEngineering/LLama/Llama-3.2-8B-Instruct-Q3_K_M.gguf")
params = Llama_params(use_cpp=True, llama_llm=llm)

run_test(
    language_1="spanish",
    language_2="german",
    no_words=None,
    llama_params=params,
    hide_used_word_for_n_words=4,
    probability_for_sentence_creation=0.6,
    use_voice=True,
    hide_correctly_translated_words=True
)