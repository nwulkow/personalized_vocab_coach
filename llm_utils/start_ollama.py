import requests

def _is_server_running(url: str) -> bool:
    try:
        return requests.get(url, timeout=1).status_code == 200
    except Exception:
        return False

def start_ollama(url: str = "http://127.0.0.1:11434/v1/models", cpu_only: bool = False):

    import subprocess
    import time
    import atexit
    import os

    # Skip startup if the server is already running
    if _is_server_running(url):
        return

    # --- 1. Start Ollama server ---
    server_cmd = ["ollama", "serve"]
    env = os.environ.copy()
    env["OLLAMA_KEEP_ALIVE"] = "-1"  # keep models loaded indefinitely
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
