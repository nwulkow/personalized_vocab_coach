from llm_utils.ollama_utils import Llama_params, respond_to_prompt
from file_utils import suggest_tag_list_for_word_pair_with_llm


def test_suggest_tag_list_for_word_pair_with_llm():
    llama_params = Llama_params(model_id="llama3:8b", use_cpp=False, url="http://127.0.0.1:11434/v1/models")

    tags = suggest_tag_list_for_word_pair_with_llm("werfen", "tirar", "German", "Spanish", llama_params)
    print("Suggested tags:", tags)


if __name__ == "__main__":
    test_suggest_tag_list_for_word_pair_with_llm()

