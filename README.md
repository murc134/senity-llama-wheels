# senity-llama-wheels

CI-Build native `llama-cpp-python`-Wheels fuer den **Senity SpeechFlow**
Runtime-Katalog (`runtime.json`, Ticket #1987). Getrennt vom App-Repo, damit
der mehrere-GB-Wheel-/Build-Kram die App-Historie nicht aufblaeht.

## Warum

Der SpeechFlow-Client laedt die native LLM-Runtime nicht ueber `pip` vom
PyPI-Index (dessen Wheels crashen auf AVX-512-losen Consumer-CPUs mit
`STATUS_ILLEGAL_INSTRUCTION`), sondern aus einem **signierten Katalog**
(`runtime.json`). Pro Plattform ein AVX2-Baseline-Wheel, adressiert ueber das
Token-Schema aus `speechflow/hardware.py`:

    <os>-<arch>-cp<pyver>      z.B. mac-arm64-cp313, win-amd64-cp313

macOS-Wheels werden mit `MACOSX_DEPLOYMENT_TARGET=11.0` gebaut, damit sie auch
auf aelteren Macs installieren (sonst traegt das Wheel die Runner-OS-Version,
z.B. `macosx_26_0`, und `pip` lehnt die Installation ab).

## Build ausloesen

Actions -> **build-wheels** -> *Run workflow*. Inputs:

| Input | Default | Zweck |
|-------|---------|-------|
| `llama_version` | `0.3.30` | PyPI-sdist-Version von `llama-cpp-python` |
| `platforms` | `all` | `all` / `mac-only` / `mac-arm64` / `mac-x86_64` / `win` / `linux` |

Die Matrix baut pro Token einen eigenen Job (cibuildwheel auf den sdist):

| Token | Runner | Backend |
|-------|--------|---------|
| `mac-arm64-cp313` | macos-14 | Metal |
| `mac-x86_64-cp313` | macos-13 | CPU AVX2 |
| `win-amd64-cp313` | windows-latest | CPU AVX2 |
| `linux-x86_64-cp313` | ubuntu-latest (manylinux_2_28) | CPU AVX2 |

Jeder Job legt sein Wheel als Artefakt unter dem Token-Namen ab.

## Vom Artefakt zum signierten Katalog

1. Artefakte herunterladen und in die Token-Struktur staffeln:

       scripts/stage_wheels.sh <run-id> ./out
       # erzeugt ./out/runtime/<token>/<wheel>.whl

2. Token-Ordner nach hetzner-operativ unter `<MODELS_DIR>/runtime/` hochladen:

       scp -r ./out/runtime/* user@hetzner:<MODELS_DIR>/runtime/

3. Auf hetzner den Katalog neu signieren (Repo `senity-speech-flow`):

       SPEECHFLOW_UPDATE_PRIVATE_KEY=... MODELS_DIR=<...> \
         python3 scripts/gen_runtime_catalog.py --base-url https://sdr.senity.ai

   Schreibt `<MODELS_DIR>/runtime.json` (Ed25519, Client-Public-Key u1).

Der Client (`speechflow/model_catalog.fetch_runtime`) zieht danach das passende
Wheel ueber `<base>/api/speechflow/runtime/<token>/<wheel>`.
