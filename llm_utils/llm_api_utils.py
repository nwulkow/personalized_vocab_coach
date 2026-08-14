from google import genai
import os


FAST_GEMINI_MODEL_CANDIDATES = [
    "gemini-2.5-flash-lite",
    "gemini-flash-latest",
]


def respond_with_gemini_fast(prompt: str, temperature: float = 0.01, max_tokens: int = 100) -> str:
    """Use the fastest available Gemini model with fallback."""
    last_error = None
    for candidate in FAST_GEMINI_MODEL_CANDIDATES:
        try:
            return respond_with_gemini(
                prompt=prompt,
                model=candidate,
                temperature=temperature,
                max_tokens=max_tokens,
            )
        except Exception as e:
            last_error = e
            continue
    if last_error is not None:
        raise last_error
    raise RuntimeError("No Gemini model candidates configured.")



def respond_with_gemini(prompt: str, model: str = "gemini-flash-latest", temperature: float = 0.01, max_tokens: int = 100) -> str:

    api_key = os.environ.get("GEMINI_API_KEY")
    client = genai.Client(api_key=api_key)

    response = client.models.generate_content(
        model=model,
        contents=prompt
    )
    return response.text