import ollama
from openai import OpenAI
import json
from llama_cpp import Llama
from llm_utils.start_ollama import start_ollama


class Llama_params:
    def __init__(
        self,
        url: str= "",
        model_id: str = "",
        cpu_only: bool = False,
        use_cpp: bool = False,
        llama_llm: Llama | None = None,
):
        self.url = url
        self.model_id = model_id
        self.cpu_only = cpu_only
        self.use_cpp = use_cpp
        self.llama_llm = llama_llm


def llama_params_from_dict(llama_params_dict: dict) -> Llama_params:
    url = llama_params_dict.get("url", "")
    model_id = llama_params_dict.get("model_id","")
    cpu_only = llama_params_dict.get("cpu_only", False)
    use_cpp = llama_params_dict.get("use_cpp", False)
    if llama_params_dict.get("model_path", None):
        from llama_cpp import Llama
        llama_llm = Llama(model_path=llama_params_dict.get("model_path"), n_gpu_layers=-1)
    else:
        llama_llm = None
    llama_params = Llama_params(
        url=url,
        model_id=model_id,
        cpu_only=cpu_only,
        use_cpp=use_cpp,
        llama_llm=llama_llm
    )
    return llama_params



def respond_with_structured_output(prompt: str, url: str, output_type: str, model_id: str = "llama3.2:1b"):
    # Connect to local Ollama server
    client = OpenAI(base_url=url, api_key="ollama")

    # Create completion with error handling
    completion = client.chat.completions.create(
        model=model_id,
        messages=[{"role": "user", "content": prompt}],
        response_format={
            "type": "json_object",
            "schema": {
                "type": "object",
                "properties": {
                    "structured_output": {"type": output_type}
                },
                "required": ["structured_output"]
            }
        }
    )
    response_content = json.loads(completion.choices[0].message.content)
    structured_value = response_content["structured_output"]
    
    # Convert to the appropriate Python type based on output_type
    if output_type == "string":
        return str(structured_value)
    elif output_type == "boolean":
        return bool(structured_value)
    elif output_type == "integer":
        return int(structured_value)
    elif output_type == "number":
        return float(structured_value)
    elif output_type == "array":
        return list(structured_value)
    else:
        return structured_value

# from ollama_start import start_ollama
# # Start Ollama server
# url = "http://127.0.0.1:11434/v1/models"
# start_ollama(url=url)
# print(
#     respond_with_structured_output(
#     prompt="Check if the number 23 is prime",
#     url=url,
#     output_type="boolean",
#     model_id="llama3.2:1b"
# )
# )


def respond_to_prompt(
    prompt: str,
    llama_params: Llama_params,
    max_tokens: int = 1000,
    temperature: float = 0.7,
    stop_phrases: list[str] | None = None
):
    if not llama_params.use_cpp:
        start_ollama(url=llama_params.url, cpu_only=llama_params.cpu_only)
        response = ollama.chat(
            model=llama_params.model_id,
            messages=[{"role": "user", "content": prompt}],#
            options={
                "temperature": temperature,
                "max_tokens": max_tokens
            }
        )
        return response["message"]["content"]
    else:
        if llama_params.llama_llm is None:
            raise ValueError("llama_llm must be provided when use_cpp is True")
        response = llama_params.llama_llm(
            prompt,
            max_tokens=max_tokens,
            temperature=temperature,
            stop=stop_phrases
        )
        return response["choices"][0]["text"]
