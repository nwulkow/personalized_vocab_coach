from word_test_runner import run_test


run_test(
    language_1="german",
    language_2="french",
    no_words=None,
    #url="http://localhost:11434/v1/models",
    #model_id="llama3.2:1b",
    hide_used_word_for_n_words=2,
    probability_for_sentence_creation=0.5,
    use_voice=True,
    hide_correctly_translated_words=True
)