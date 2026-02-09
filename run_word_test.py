from ollama_utils import Llama_params
from word_test_runner import run_test
from llama_cpp import Llama


llm = Llama(model_path="/Users/niklaswulkow/ResearchEngineering/LLama/gemma-3-27B-it-QAT-Q4_0.gguf", n_gpu_layers=-1)
params = Llama_params(use_cpp=True, llama_llm=llm)

run_test(
    language_1="english",
    language_2="german",
    no_words=None,
    llama_params=params,
    hide_used_word_for_n_words=4,
    probability_for_sentence_creation=0.6,
    use_voice=True,
    hide_correctly_translated_words=True,
    description_for_word_filtering="Verbs only",
    max_num_words_in_created_sentence=8,
    language_level_for_created_sentence="C2",
    be_stringent=True
)