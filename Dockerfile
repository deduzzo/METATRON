# ─────────────────────────────────────────────
# METATRON — AI Penetration Testing Assistant
# Container Debian-based con tutti i tool di recon
# ─────────────────────────────────────────────
FROM python:3.12-slim-bookworm

LABEL org.opencontainers.image.title="METATRON" \
      org.opencontainers.image.description="AI-powered pentest assistant (containerized)" \
      org.opencontainers.image.source="https://github.com/sooryathejas/METATRON"

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

# ─────────────────────────────────────────────
# Tool di sistema necessari ai recon di METATRON
#   - nmap, whois, whatweb, curl, dnsutils, nikto
#   - default-mysql-client utile per debug verso il DB
#   - build-essential + libmariadb-dev per costruire eventuali wheel
# nikto e whatweb su Debian bookworm sono nel componente "contrib",
# quindi abilitiamo contrib + non-free prima di apt-get update.
# ─────────────────────────────────────────────
RUN sed -i 's/^Components: main$/Components: main contrib non-free non-free-firmware/' \
        /etc/apt/sources.list.d/debian.sources \
    && apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        dnsutils \
        whois \
        nmap \
        whatweb \
        nikto \
        default-mysql-client \
        build-essential \
        libmariadb-dev \
        pkg-config \
        tini \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Cartella di lavoro
WORKDIR /app

# Installa le dipendenze Python (cache layer)
COPY requirements.txt /app/requirements.txt
RUN pip install --upgrade pip \
    && pip install -r /app/requirements.txt

# Copia il resto del codice
COPY . /app

# Cartella di output per export PDF/HTML (montata come volume)
RUN mkdir -p /app/exports

# tini come init -> gestisce i segnali e lo zombie reaping
ENTRYPOINT ["/usr/bin/tini", "--"]

# CLI interattiva: avvio default
CMD ["python", "metatron.py"]
