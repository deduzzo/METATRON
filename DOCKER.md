# METATRON in Docker (su macOS)

Guida per usare METATRON dentro container Docker partendo da un Mac, mantenendo
**Ollama nativo** (per sfruttare l'accelerazione Metal/Apple Silicon) e
spostando in container tutto il resto: l'app Python, i tool di recon
(`nmap`, `whois`, `whatweb`, `nikto`, `dig`, `curl`) e MariaDB.

## Architettura

```
   ┌────────────────────────┐         ┌─────────────────────┐
   │  Mac host              │         │  Docker network     │
   │                        │         │  metatron-net       │
   │  ┌──────────────────┐  │         │                     │
   │  │ Ollama nativo    │◄─┼─────────┤  metatron-app       │
   │  │ :11434 (Metal)   │  │  HTTP   │  (python + nmap…)   │
   │  └──────────────────┘  │         │          │          │
   │                        │         │          │ TCP      │
   │  ./exports  ──────────►│ volume  │          ▼          │
   │                        │         │  metatron-mariadb   │
   └────────────────────────┘         └─────────────────────┘
```

Il container `metatron-app` raggiunge Ollama tramite `host.docker.internal:11434`
(meccanismo gestito da Docker Desktop su macOS).

## Prerequisiti

- macOS con [Docker Desktop](https://www.docker.com/products/docker-desktop/) installato e avviato
- [Ollama](https://ollama.com/download) installato nativamente su macOS
- ~10 GB liberi per scaricare il modello base

## Setup (una volta sola)

### 1. Configurazione

```bash
cp .env.example .env
# (opzionale) modifica password / nomi nel file .env
```

### 2. Setup del modello Ollama sul Mac

Lo script verifica i prerequisiti, scarica il modello base e crea
il modello custom `metatron-qwen` dal `Modelfile`.

```bash
./docker/setup-ollama.sh
```

Lascia poi `ollama serve` (o l'app Ollama) attivo in background.

> Se hai meno di 8 GB di RAM, modifica prima il `Modelfile` mettendo
> `FROM huihui_ai/qwen3.5-abliterated:4b` ed esporta
> `BASE_MODEL=huihui_ai/qwen3.5-abliterated:4b` prima di lanciare lo script.

### 3. Build delle immagini

```bash
docker compose build
```

## Uso quotidiano

### Avvio interattivo (CLI di METATRON)

```bash
docker compose run --rm metatron
```

`run --rm` apre la TUI in foreground e ripulisce il container alla chiusura.
MariaDB resta su con `up -d` se la avvii separatamente.

### Avvio con servizi staccati + accesso shell

```bash
# Avvia MariaDB in background
docker compose up -d mariadb

# Apri una shell nel container app
docker compose run --rm metatron bash

# Dalla shell:
python metatron.py
```

### Stop / cleanup

```bash
docker compose down            # ferma e rimuove i container
docker compose down -v         # rimuove anche il volume DB (azzera lo storico)
```

## File generati

I report PDF/HTML esportati dall'app finiscono nella cartella `./exports/`
sul Mac (volume montato in `/app/exports` dentro il container).

## Connessione manuale al DB

```bash
# Da host (porta 3306 esposta solo su 127.0.0.1)
mysql -h 127.0.0.1 -P 3306 -u metatron -p123 metatron

# Da dentro un altro container
docker compose exec mariadb mariadb -u metatron -p123 metatron
```

## Variabili d'ambiente principali

| Variabile        | Default                                       | Descrizione                              |
|------------------|-----------------------------------------------|------------------------------------------|
| `DB_HOST`        | `mariadb` (in compose) / `localhost` (locale) | hostname del DB                          |
| `DB_PORT`        | `3306`                                        | porta del DB                             |
| `DB_USER`        | `metatron`                                    | utente DB                                |
| `DB_PASS`        | `123`                                         | password DB                              |
| `DB_NAME`        | `metatron`                                    | nome database                            |
| `OLLAMA_URL`     | `http://host.docker.internal:11434/api/chat`  | endpoint Ollama (host nativo)            |
| `OLLAMA_MODEL`   | `metatron-qwen`                               | nome modello custom                      |
| `OLLAMA_TIMEOUT` | `600`                                         | timeout HTTP verso Ollama (s)            |

Le stesse variabili funzionano anche **fuori da Docker**: il codice ha
fallback ai valori originali, quindi i comandi del README upstream
restano validi.

## Note di rete e capabilities

Il container `metatron` ha `cap_add: NET_RAW, NET_ADMIN` per permettere a
`nmap` SYN-scan e raw-socket. Senza queste capability, `nmap` ricade
automaticamente in modalita' connect-scan.

Il container **non** apre porte verso l'esterno: tutta la comunicazione
in uscita (scan, DuckDuckGo, Ollama) parte dall'host.

## Troubleshooting

**"Connection refused" verso Ollama**
- Verifica che `ollama serve` sia attivo: `curl http://localhost:11434/api/tags`
- Su Linux puro (non Mac), `host.docker.internal` e' mappato dalla riga
  `extra_hosts: "host.docker.internal:host-gateway"` nel compose.

**MariaDB non parte / "access denied"**
- Se hai cambiato le password nel `.env` *dopo* il primo avvio, devi
  resettare il volume: `docker compose down -v && docker compose up -d mariadb`.
  L'init SQL viene eseguito **solo** quando il volume e' vuoto.

**`nmap` lentissimo**
- Verifica le capability: `docker compose exec metatron nmap --privileged --version`.
- In alternativa lancia `nmap` con `-sT` (TCP connect scan) che non richiede privilegi.
