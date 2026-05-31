from google import genai
import os



def respond_with_gemini(prompt: str, model: str = "gemini-flash-latest", temperature: float = 0.01, max_tokens: int = 100) -> str:

    api_key = os.environ.get("GEMINI_API_KEY")
    client = genai.Client(api_key=api_key)

    response = client.models.generate_content(
        model=model,
        contents=prompt
    )
    return response.text