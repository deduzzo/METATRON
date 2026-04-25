#!/usr/bin/env bash
# ─────────────────────────────────────────────
# METATRON — setup-ollama.sh
# Da eseguire UNA VOLTA sul Mac host.
# Installa il modello base e crea il modello custom 'metatron-qwen'
# usando il Modelfile incluso nel repo.
# ─────────────────────────────────────────────
set -euo pipefail

# Permette override da env
BASE_MODEL="${BASE_MODEL:-huihui_ai/qwen3.5-abliterated:9b}"
CUSTOM_MODEL="${CUSTOM_MODEL:-metatron-qwen}"
MODELFILE="${MODELFILE:-Modelfile}"

bold() { printf "\033[1m%s\033[0m\n" "$*"; }
info() { printf "\033[36m[i]\033[0m %s\n" "$*"; }
ok()   { printf "\033[32m[+]\033[0m %s\n" "$*"; }
err()  { printf "\033[31m[!]\033[0m %s\n" "$*" >&2; }

# 1) Verifica che ollama sia installato
if ! command -v ollama >/dev/null 2>&1; then
    err "ollama non e' installato sull'host."
    echo "    Installalo da https://ollama.com/download (scegli macOS)"
    echo "    oppure: brew install ollama"
    exit 1
fi
ok "ollama trovato: $(ollama --version 2>/dev/null || echo 'unknown')"

# 2) Verifica che il daemon ollama sia raggiungibile
if ! curl -s --max-time 3 http://localhost:11434/api/tags >/dev/null; then
    err "il daemon ollama non risponde su http://localhost:11434"
    echo "    Avvialo con:  ollama serve"
    echo "    (oppure apri l'app Ollama.app su macOS)"
    exit 1
fi
ok "daemon ollama attivo su :11434"

# 3) Pull del modello base se assente
if ollama list | awk '{print $1}' | grep -q "^${BASE_MODEL}$"; then
    ok "modello base gia' presente: ${BASE_MODEL}"
else
    info "scarico il modello base: ${BASE_MODEL} (puo' richiedere diversi GB)"
    ollama pull "${BASE_MODEL}"
fi

# 4) Localizza il Modelfile (lo script sta in docker/, il Modelfile in root)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "${SCRIPT_DIR}/.." && pwd )"
MODELFILE_PATH="${REPO_ROOT}/${MODELFILE}"

if [[ ! -f "${MODELFILE_PATH}" ]]; then
    err "Modelfile non trovato in ${MODELFILE_PATH}"
    exit 1
fi

# 5) Crea il modello custom
info "creo il modello custom '${CUSTOM_MODEL}' dal Modelfile"
ollama create "${CUSTOM_MODEL}" -f "${MODELFILE_PATH}"
ok "modello '${CUSTOM_MODEL}' pronto"

bold ""
bold "Setup Ollama completato."
echo  "Lascia 'ollama serve' (o l'app Ollama) attivo sul Mac, poi avvia METATRON con:"
echo  "    docker compose up --build"
