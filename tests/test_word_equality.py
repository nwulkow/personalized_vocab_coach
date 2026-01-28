from ollama_start import start_ollama


def test_equality():
    """Test the check_equality function."""
    from word_comparisons import check_equality

    # Test identical words
    assert check_equality("apple", "apple") == True
    # Test different words
    assert check_equality("apple", "banana") == False


def test_meaning_equality():
    """Test the check_equality function with meaning comparison using Ollama model."""
    from word_comparisons import check_equality

    ollama_model_id = "llama3.2:1b"  # Replace with your actual Ollama model ID

    # Test words with same meaning
    assert check_equality("car", "automobile", ollama_model_id=ollama_model_id) == True
    # Test words with different meanings
    assert check_equality("car", "banana", ollama_model_id=ollama_model_id) == False



if __name__ == "__main__":

    start_ollama()
    test_equality()
    test_meaning_equality()