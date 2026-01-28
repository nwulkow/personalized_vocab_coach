from create_text_and_voice import create_voice_from_text



if __name__ == "__main__":
    create_voice_from_text("Hello, this is a test.", language="english")

    create_voice_from_text("Il y a des carottes ici", language="french")

    create_voice_from_text("Das ist ein Test", language="german")

    create_voice_from_text("Hola, esto es una prueba.", language="spanish")