import ollama

def start_ollama(url: str = "http://127.0.0.1:11434/v1/models", cpu_only: bool = False):

    import subprocess
    import time
    import requests
    import atexit
    import os

    # --- 1. Start Ollama server ---
    server_cmd = ["ollama", "serve"]
    env = os.environ.copy()
    if cpu_only:
        env["OLLAMA_NUM_GPU"] = "0"
        env["OLLAMA_LLM_LIBRARY"] = "cpu"
    server_proc = subprocess.Popen(
        server_cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env,
    )

    # Ensure server is terminated on exit
    atexit.register(lambda: server_proc.terminate())

    # --- 2. Wait for server to be ready ---
    def wait_for_server(url=url, timeout=30):
        start = time.time()
        while time.time() - start < timeout:
            try:
                resp = requests.get(url)
                if resp.status_code == 200:
                    print("Ollama server ready!")
                    return True
            except requests.exceptions.ConnectionError:
                pass
            time.sleep(1)
        raise RuntimeError("Ollama server did not start in time")

    wait_for_server()

    # --- 3. Use the model ---
    # Pull model if needed
    # subprocess.run(["ollama", "pull", "llama3:3b"])


#start_ollama(url="http://127.0.0.1:11434/v1/models")



# --- 4. The server will auto-close on exit via atexit ---
