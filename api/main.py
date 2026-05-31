from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import asyncio
import pandas as pd
from datetime import datetime
import os
from dotenv import load_dotenv
load_dotenv()
from llm_utils.ollama_utils import llama_params_from_dict
from translator_utils import translate_text, show_multiple_translations
from word_test_runner import sample_word, filter_word_list_by_description
from file_utils import add_word_pair_to_word_list, add_tag_list_to_word_pair, get_word_list_file_name
from word_comparisons import check_equality

# Pydantic models for request bodies
class CreateWordRequest(BaseModel):
    words_language_1: list[str]
    words_language_2: list[str]
    language_1: str
    language_2: str
    probability_for_sentence_creation: float
    max_num_words_in_created_sentence: int = 10
    language_level_for_created_sentence: str = "C1"
    original_indices: list[int] | None = None
    remark: str | None = None

class WordPair(BaseModel):
    word_language_1: str
    word_language_2: str
    date_added: str | None = None
    tags: str | None = None

class SaveWordListRequest(BaseModel):
    language_1: str
    language_2: str
    words: list[WordPair]
    
app = FastAPI(docs_url="/swagger")

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, replace with specific origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

#llama_params_dict = {
#    "use_cpp": True, "model_path": "/Users/niklaswulkow/ResearchEngineering/LLama/gemma-3-27B-it-QAT-Q4_0.gguf"
#}
llama_params_dict = {
    "use_cpp": False,
    "model_id": "llama3:8b",
    "url": "http://127.0.0.1:11434/v1/models"
}
# llama_params_dict = None
llama_params = llama_params_from_dict(llama_params_dict) if llama_params_dict is not None else None

@app.get("/")
def root():
    return {"status": "running"}

@app.get("/llm_info")
def llm_info():
    """Return information about the currently configured LLM."""
    import os
    if llama_params is None:
        return {"llm_name": None, "display": "No LLM active"}
    use_cpp = getattr(llama_params, 'use_cpp', False)
    if use_cpp:
        model_path = getattr(llama_params, 'model_path', None)
        model_name = os.path.basename(model_path) if model_path else None
    else:
        model_name = getattr(llama_params, 'model_id', None)
    if model_name:
        return {"llm_name": model_name, "display": model_name}
    return {"llm_name": None, "display": "No LLM active"}

@app.post("/translate")
def translate(text: str, src_language: str, dest_language: str, speak_translated: bool):
    
    translated_text = asyncio.run(translate_text(text, src_language, dest_language, speak_translated=speak_translated))
    return {"translated_text": translated_text}


@app.post("/show_alternatives")
def show_alternatives(word: str, src_language: str, dest_language: str, google_translation: str = None):
    """Get multiple alternative translations for a word using the LLM."""
    if llama_params is None:
        return {"alternatives": [], "error": "No LLM configured"}
    alternatives = show_multiple_translations(
        word, src_language, dest_language, llama_params,
        google_translation=google_translation
    )
    return {"alternatives": alternatives}


@app.post("/create_word")
def create_word(request: CreateWordRequest):
    
    words = pd.DataFrame({
        request.language_1.capitalize(): request.words_language_1, 
        request.language_2.capitalize(): request.words_language_2
    })

    # If caller provided original indices (mapping to the full word list), set them as the DataFrame index
    if request.original_indices is not None and len(request.original_indices) == len(words):
        words.index = request.original_indices
    word_language_1, word_language_2, word_index, original_word_language_1 = sample_word(
        words,
        request.language_1,
        request.language_2,
        request.probability_for_sentence_creation,
        llama_params,
        request.max_num_words_in_created_sentence,
        request.language_level_for_created_sentence,
        remark=request.remark
    )

    # Ensure the returned index is a plain Python int for JSON serialization
    if word_index is not None:
        try:
            word_index = int(word_index)
        except Exception:
            pass

    return {
        "word": {
            "word_language_1": word_language_1,
            "word_language_2": word_language_2,
            "word_index": word_index,
            "original_word_language_1": original_word_language_1
        }
    }


@app.get("/tags")
def get_all_tags(language_1: str = None, language_2: str = None):
    """Return all unique tags. If language_1 and language_2 are given, only from that word list."""
    import os
    word_lists_dir = "word_lists"
    all_tags = set()

    def _extract_tags_from_file(filepath):
        try:
            df = pd.read_csv(filepath)
            if "tags" in df.columns:
                for cell in df["tags"].dropna():
                    for tag in str(cell).split(";"):
                        tag = tag.strip()
                        if tag:
                            all_tags.add(tag)
        except Exception:
            pass

    if language_1 and language_2:
        try:
            filepath = get_word_list_file_name(language_1, language_2)
            _extract_tags_from_file(filepath)
        except Exception:
            pass
    else:
        for filename in sorted(os.listdir(word_lists_dir)):
            if filename.endswith(".csv"):
                _extract_tags_from_file(os.path.join(word_lists_dir, filename))

    return {"tags": sorted(all_tags)}


@app.post("/add_word_pair")
def add_word_pair(
    word_language_1: str,
    word_language_2: str,
    language_1: str,
    language_2: str,
    tags: str = ""
):
    """Add a word pair to the word list, optionally with semicolon-separated tags."""
    add_word_pair_to_word_list(word_language_1, word_language_2, language_1, language_2)
    if tags:
        tag_list = [t.strip() for t in tags.split(";") if t.strip()]
        if tag_list:
            add_tag_list_to_word_pair(word_language_1, word_language_2, language_1, language_2, tag_list)
    return {"status": "success", "message": "Word pair added to list"}


@app.post("/suggest_tags")
def suggest_tags_endpoint(word_1: str, word_2: str, language_1: str, language_2: str):
    """Suggest tags for a word pair using the configured LLM."""
    if llama_params is None:
        return {"tags": [], "error": "No LLM configured"}
    try:
        from file_utils import suggest_tag_list_for_word_pair_with_llm
        tags = suggest_tag_list_for_word_pair_with_llm(word_1, word_2, language_1, language_2, llama_params)
        return {"tags": tags}
    except Exception as e:
        return {"tags": [], "error": str(e)}


@app.get("/word_lists")
def get_available_word_lists():
    """Return all available word list language pairs derived from CSV filenames."""
    import os
    word_lists_dir = "word_lists"
    pairs = []
    for filename in sorted(os.listdir(word_lists_dir)):
        if filename.endswith(".csv"):
            name = filename[:-4]  # strip .csv
            parts = name.split("_")
            if len(parts) == 2:
                pairs.append({
                    "key": name,
                    "language_1": parts[0],
                    "language_2": parts[1],
                    "label": f"{parts[0].capitalize()} \u2194 {parts[1].capitalize()}"
                })
    return {"word_lists": pairs}


@app.get("/word_list")
def get_word_list_endpoint(language_1: str, language_2: str, start_date_added: str = None, end_date_added: str = None):
    """Get the word list for a given language pair."""
    try:
        word_list_path = get_word_list_file_name(language_1, language_2)
        words = pd.read_csv(word_list_path)

        if start_date_added is not None:
            start_date_added = pd.to_datetime(start_date_added)
            words = words[pd.to_datetime(words["date_added"]) >= start_date_added]
        if end_date_added is not None:
            end_date_added = pd.to_datetime(end_date_added)
            words = words[pd.to_datetime(words["date_added"]) <= end_date_added]

        # Replace NaN with empty string so JSON serialization produces valid output
        words = words.fillna('')
        words = words.to_dict('records')
        return {"words": words}
    except ValueError as e:
        return {"words": [], "error": str(e)}


@app.post("/save_word_list")
def save_word_list_endpoint(request: SaveWordListRequest):
    """Save/replace the entire word list for a given language pair."""
    try:
        word_list_path = get_word_list_file_name(request.language_1, request.language_2)
        
        # Create DataFrame with the new words
        lang1_cap = request.language_1.capitalize()
        lang2_cap = request.language_2.capitalize()
        
        now_str = datetime.now().strftime('%Y-%m-%d %H:%M')
        df = pd.DataFrame({
            lang1_cap: [word.word_language_1 for word in request.words],
            lang2_cap: [word.word_language_2 for word in request.words],
            'date_added': [word.date_added if word.date_added else now_str for word in request.words],
            'tags': [word.tags if word.tags is not None else '' for word in request.words]
        })
        
        # Save to CSV (overwriting the old file)
        df.to_csv(word_list_path, index=False)
        
        return {"status": "success", "message": f"Saved {len(request.words)} word pairs"}
    except Exception as e:
        return {"status": "error", "message": str(e)}


@app.post("/check_translation")
def check_translation(user_translation: str, correct_translation: str, be_stringent: bool = False, word_to_pay_attention_to: str | None = None):
    """Check if a user's translation is correct."""
    is_correct = check_equality(
        user_translation,
        correct_translation,
        llama_params=llama_params,
        be_stringent=be_stringent,
        word_to_pay_attention_to=word_to_pay_attention_to
    )
    return {"is_correct": is_correct}


@app.post("/filter_words")
def filter_words(language: str, description: str, language_pair: str = None):
    """Filter words based on a description using LLM.
    
    Args:
        language: The language to filter (e.g., 'german', 'english')
        description: The description to filter by (e.g., 'verbs only')
        language_pair: Optional language pair in format 'german_english' to use specific word list
    """
    if llama_params is None:
        return {"filtered_words": [], "error": "No LLM configured"}
    try:
        # If language_pair is provided, use that specific word list
        if language_pair:
            parts = language_pair.split('_')
            if len(parts) == 2:
                word_list_path = get_word_list_file_name(parts[0], parts[1])
                words_df = pd.read_csv(word_list_path)
            else:
                # Fall back to finding all word lists containing the language
                import os
                word_lists_dir = "word_lists"
                all_words = []
                
                for filename in os.listdir(word_lists_dir):
                    if filename.endswith(".csv") and language in filename:
                        filepath = os.path.join(word_lists_dir, filename)
                        words_df_temp = pd.read_csv(filepath)
                        all_words.append(words_df_temp)
                
                if not all_words:
                    return {"filtered_words": []}
                
                words_df = pd.concat(all_words, ignore_index=True).drop_duplicates()
        else:
            # Find all CSV files containing the language
            import os
            word_lists_dir = "word_lists"
            all_words = []
            
            for filename in os.listdir(word_lists_dir):
                if filename.endswith(".csv") and language in filename:
                    filepath = os.path.join(word_lists_dir, filename)
                    words_df_temp = pd.read_csv(filepath)
                    all_words.append(words_df_temp)
            
            if not all_words:
                return {"filtered_words": []}
            
            words_df = pd.concat(all_words, ignore_index=True).drop_duplicates()
        
        # Filter using the description
        filtered_df = filter_word_list_by_description(
            words_df,
            language,
            description,
            llama_params
        )
        
        return {"filtered_words": filtered_df.to_dict('records')}
    except Exception as e:
        return {"filtered_words": [], "error": str(e)}


# ── Text Evaluation ─────────────────────────────────────────────────────────

class EvaluateTextRequest(BaseModel):
    text: str
    words: list[str]
    language: str
    level: str = "Intermediate"  # Basic | Intermediate | Advanced

class SampleWordsRequest(BaseModel):
    language: str
    primary_language: str
    no_words: int = 1
    tags: list[str] = []
    tag_filter_mode: str = "include"   # include | exclude
    tag_match_mode: str = "any"        # any | all
    description: str = ""
    start_date: str = ""
    end_date: str = ""


@app.get("/primary_language")
def get_primary_language():
    """Return the primary language from .env."""
    return {"primary_language": os.getenv("PRIMARY_LANGUAGE", "german")}


@app.post("/sample_words_for_writing")
def sample_words_for_writing(request: SampleWordsRequest):
    """Sample N words from a word list for a writing exercise, with optional tag / date filtering."""
    from word_test_runner import filter_word_list_by_tags
    try:
        word_list_path = get_word_list_file_name(request.primary_language, request.language)
        words_df = pd.read_csv(word_list_path).fillna('')

        # Date filter
        if request.start_date:
            words_df = words_df[pd.to_datetime(words_df["date_added"], errors='coerce') >= pd.to_datetime(request.start_date)]
        if request.end_date:
            words_df = words_df[pd.to_datetime(words_df["date_added"], errors='coerce') <= pd.to_datetime(request.end_date)]

        # Tag filter
        if request.tags:
            exclude = request.tag_filter_mode == "exclude"
            intersection = request.tag_match_mode == "all"
            words_df = filter_word_list_by_tags(words_df, request.tags, exclude_words_with_tag=exclude, intersection=intersection)
            if words_df is None or len(words_df) == 0:
                return {"words": [], "error": "No words match the tag filter."}

        # Description filter
        if request.description.strip() and llama_params is not None:
            filtered = filter_word_list_by_description(words_df, request.language, request.description, llama_params)
            if filtered is not None and len(filtered) > 0:
                words_df = filtered

        lang_col = request.language.capitalize()
        if lang_col not in words_df.columns:
            return {"words": [], "error": f"Column '{lang_col}' not found in word list."}

        available = words_df[lang_col].dropna().unique().tolist()
        available = [w for w in available if str(w).strip()]

        if not available:
            return {"words": [], "error": "No words available after filtering."}

        n = min(request.no_words, len(available))
        sampled = pd.Series(available).sample(n).tolist()
        return {"words": sampled}
    except Exception as e:
        return {"words": [], "error": str(e)}


@app.post("/evaluate_text")
def evaluate_text(request: EvaluateTextRequest):
    """Evaluate a user-written text using Gemini and return feedback."""
    from llm_utils.llm_api_utils import respond_with_gemini
    try:
        words_str = ", ".join(f'"{w}"' for w in request.words)
        level_hint = {
            "Basic": "Focus only on very basic mistakes (word order, missing articles, verb conjugations). Do not point out subtle issues.",
            "Intermediate": "Check for common mistakes that hinder clear communication, but do not be overly strict about minor stylistic issues.",
            "Advanced": "Be very thorough — check for subtle mistakes, nuances, idiomatic expressions, and stylistic issues.",
        }.get(request.level, "")
        prompt = (
            f"The user was asked to write a text in {request.language.capitalize()} "
            f"that contains the following word(s): {words_str}.\n\n"
            f"Their text: \"{request.text}\"\n\n"
            f"Please:\n"
            f"1. Check whether the required word(s) appear (or a grammatically correct form of them).\n"
            f"2. Check the text for language mistakes and explain them briefly and concisely.\n"
            f"If there are no mistakes, only say \"No mistakes found.\"\n"
            f"{level_hint}"
        )
        feedback = respond_with_gemini(prompt)
        return {"feedback": feedback.strip()}
    except Exception as e:
        return {"feedback": "", "error": str(e)}
