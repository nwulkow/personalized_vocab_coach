import click


@click.command()
@click.argument("text", type=str)
@click.argument("src_language", type=str)
@click.argument("dest_language", type=str)
@click.option("--add_to_word_list", is_flag=True, help="Add the translated word pair to the word list.")
@click.option("--speak_translated", is_flag=True, help="Speak the translated text aloud.")
def run_translator_cmd(text: str, src_language: str, dest_language: str, add_to_word_list: bool, speak_translated: bool):
    """Translate TEXT from SRC_LANGUAGE to DEST_LANGUAGE and print the result."""
    from translator_utils import translate_text
    import asyncio

    translated_text = asyncio.run(translate_text(text, src_language, dest_language, add_to_word_list=add_to_word_list, speak_translated=speak_translated))
    print(f"Translated text: {translated_text}")

# example: python run_translator_cmd.py "House" "en" "de" --add_to_word_list

if __name__ == "__main__":
    run_translator_cmd()