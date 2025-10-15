# Konzept: Lokal betriebener LLM-Server auf Ubuntu mit LUKS-Verschlüsselung

## Zielsetzung und Rahmenbedingungen
- Bereitstellung eines lokalen LLM-Servers auf einem gehärteten Ubuntu-System.
- Speicherung sensibler Daten auf vollständig verschlüsselten Datenträgern (LUKS-basiert).
- Strikte Netzwerkkontrolle: Betrieb im Offline-Modus bzw. nur über dedizierte, freigegebene Verbindungen.
- Fokus auf interne Wissensabfrage, Dokumentenanalyse und Entscheidungsunterstützung; kein Coding-Assistant-Einsatz.

## Empfohlene Hardwareplattform

| Komponente        | Empfehlung / Produktbezeichnung |
| ----------------- | -------------------------------- |
| Mainboard         | ASUS PRIME Z790-P D5 (ATX, DDR5, Intel LAN, 2× M.2, Z790) |
| CPU               | Intel Core i7-13700K (Sockel 1700, 16 Kerne, 24 Threads) |
| GPU               | NVIDIA RTX 3090, 24 GB (z. B. ASUS TUF, MSI Gaming Trio) |
| RAM               | 64 GB DDR5 (2×32 GB, ≥ 5600 MHz, z. B. Kingston Fury) |
| SSD               | Samsung 990 PRO 2 TB NVMe PCIe 4.0 |
| Netzteil          | be quiet! Pure Power 12 M 1000 W ATX 3.0, 80+ Gold, modular |
| Gehäuse           | Fractal Design Meshify 2 (ATX, luftstromoptimiert) |
| CPU-Kühler        | be quiet! Dark Rock 4 (für Intel LGA1700) |
| Betriebssystem    | Ubuntu 22.04 LTS (https://ubuntu.com/download/server) |

Die Komponenten sind auf hohe Speicherbandbreite, GPU-Beschleunigung und ausreichende Leistungsreserven für rechenintensive Transformermodelle ausgelegt. Alternativ können ECC-fähige Workstation-Plattformen genutzt werden, wenn erhöhte Anforderungen an Datenintegrität bestehen.

## Infrastruktur und Software-Stack
1. **Basisbetriebssystem**
   - Ubuntu Server LTS, minimales Installationsprofil ohne zusätzliche Desktop-Komponenten.
   - Vollständige Festplattenverschlüsselung mittels LUKS2 (dm-crypt) mit TPM-gestützter Schlüsselverwaltung oder manuellem Passphrase-Entry beim Boot.

2. **Virtualisierung / Containerisierung (optional)**
   - Einsatz von Proxmox oder VMware ESXi bei Bedarf an Multi-VM-Umgebung.
   - Für Containerisierung: Docker oder Podman mit rootless-Konfiguration; bevorzugt Podman wegen geringerer Angriffsfläche.

3. **LLM-Serving-Schicht**
   - Einsatz von Open-Source-Frameworks wie `text-generation-inference`, `vLLM`, `llama.cpp` oder `Ollama`.
   - GPU-Unterstützung (CUDA / ROCm) je nach Hardware; fallback auf CPU für kleinere Modelle.
   - Reverse-Proxy (nginx oder Traefik) ausschließlich für interne Clients im Intranet.

4. **Zugriffskontrolle und Authentifizierung**
   - Zentrale Authentifizierung über Keycloak oder OpenID Connect Provider.
   - Role-Based Access Control (RBAC) für differenzierte Zugriffsstufen (Admin, Modell-Operator, Nutzer).
   - Audit-Logging (z. B. mit Loki + Grafana) für nachvollziehbare Nutzungshistorie.

5. **Systemhärtung**
   - Deaktivieren nicht benötigter Dienste, `ufw`/`nftables` strikt konfigurieren.
   - Automatisierte Konfigurationsverwaltung via Ansible; Dokumentation aller Änderungen (Infrastructure as Code).

## Installation, Festplattenverschlüsselung und Basis-Härtung

1. **Ubuntu-Installation mit LUKS2**
   - Während der Installation „Benutzerdefinierte Installation“ wählen und alle relevanten Partitionen (inkl. Boot außer EFI) mit LUKS2 verschlüsseln.
   - Sichere Passphrase definieren; optional TPM 2.0 und `systemd-cryptenroll` nutzen, um automatische Entschlüsselung nur auf vertrauenswürdiger Hardware zu erlauben.
   - Beispiel manuelle Einrichtung auf separatem Installationsmedium:

     ```bash
     sudo cryptsetup luksFormat /dev/nvme0n1p3
     sudo cryptsetup open /dev/nvme0n1p3 cryptroot
     sudo pvcreate /dev/mapper/cryptroot
     sudo vgcreate vg0 /dev/mapper/cryptroot
     sudo lvcreate -L 80G -n root vg0
     sudo lvcreate -l 100%FREE -n data vg0
     ```

   - Nach der Installation sicherstellen, dass `GRUB_CMDLINE_LINUX_DEFAULT="quiet splash apparmor=1 security=apparmor"` gesetzt ist und `update-grub` ausführen.

2. **Basis-Härtung**
   - Sofort nach dem ersten Boot `sudo apt update && sudo apt dist-upgrade` über internes Offline-Repository durchführen.
   - Unnötige Dienste (`avahi-daemon`, `cups`, etc.) entfernen, SSH-Zugriff auf Schlüssel-Authentifizierung beschränken und `fail2ban` aktivieren.
   - `ufw` auf „deny outgoing“ konfigurieren und nur manuell freigegebene Ziele erlauben.

3. **Offline-Update-Strategie**
   - Spiegel-Server oder signierte Offline-Medien für Paketupdates nutzen.
   - Über `debmirror` oder `aptly` interne Paketspiegel pflegen.

4. **Integritätsschutz**
   - Secure Boot aktivieren, Firmware regelmäßig aktualisieren und Hash-basierte Integritätsprüfungen (`aide`, `tripwire`) einplanen.

## Docker- und GPU-Stack installieren

### Manuelle Installation (Schritt-für-Schritt)

```bash
sudo apt remove docker docker-engine docker.io containerd runc

sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \"
  "https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo systemctl enable --now docker
```

### Automatisiertes Setup für Docker & NVIDIA Container Toolkit

```bash
#!/bin/bash
set -euo pipefail

echo "=== Docker & NVIDIA Container Toolkit Setup für vLLM mit RTX 3090 ==="

sudo apt remove -y docker docker-engine docker.io containerd runc || true

sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \"
  "https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo systemctl enable --now docker

sudo apt install -y nvidia-driver-535 nvidia-utils-535

curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
  sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -sSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt update
sudo apt install -y nvidia-container-toolkit

sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

### Funktionstest

```bash
mkdir -p ~/dockerdata/tool/01_schneller_gpu_test
cat <<'EOF' > ~/dockerdata/tool/01_schneller_gpu_test/docker-compose.yml
services:
  cuda:
    image: nvidia/cuda:12.2.0-base-ubuntu22.04
    command: ["nvidia-smi"]
    gpus: all
    restart: "no"
EOF

cd ~/dockerdata/tool/01_schneller_gpu_test
docker compose up
```

Der Test sollte eine Ausgabe von `nvidia-smi` mit erkannter RTX 3090 liefern. Anschließend `docker compose down` ausführen und das Verzeichnis wieder entfernen.

## Ollama und vLLM per Docker Compose betreiben

1. **Gemeinsames Netzwerk und Persistenz**

   ```bash
   mkdir -p /dockerdata/{ollama,vllm}
   sudo chown -R $USER:$USER /dockerdata
   docker network create llm-internal
   ```

2. **Ollama (olama) Dienst**

   ```yaml
   # /dockerdata/ollama/docker-compose.yml
   services:
     ollama:
       image: ollama/ollama:latest
       container_name: ollama
       restart: unless-stopped
       networks:
         - llm-internal
       volumes:
         - /dockerdata/ollama/data:/root/.ollama
       environment:
         - OLLAMA_KEEP_ALIVE=24h
       deploy:
         resources:
           reservations:
             devices:
               - driver: nvidia
                 count: 1
                 capabilities: [gpu]
   networks:
     llm-internal:
       external: true
   ```

   Starten mit `docker compose up -d` und gewünschte Modelle offline importieren (`ollama serve`, `ollama pull <modell>` über vorbereitete Datenträger).

3. **vLLM Dienst**

   ```yaml
   # /dockerdata/vllm/docker-compose.yml
   services:
     vllm:
       image: vllm/vllm-openai:latest
       container_name: vllm
       command: ["--model", "/models/llama-2-13b", "--disable-log-requests"]
       restart: unless-stopped
       networks:
         - llm-internal
       volumes:
         - /dockerdata/vllm/models:/models:ro
       ports:
         - "127.0.0.1:8000:8000"
       deploy:
         resources:
           reservations:
             devices:
               - driver: nvidia
                 count: 1
                 capabilities: [gpu]
   networks:
     llm-internal:
       external: true
   ```

   Modelle werden nur aus vorher geprüften, signierten Archiven entpackt (`/dockerdata/vllm/models`). Zugriff aus dem internen Netz erfolgt über einen nachgeschalteten Reverse Proxy mit Authentifizierung.

## Datenbefüllung und Wissensbasis
1. **Datenquellen**
   - Interne Dokumentationen, Wikis, Richtlinien, FAQ-Listen.
   - Optionale Anbindung an strukturierte Daten (z. B. SQL-Dumps) via ETL-Prozess.

2. **Aufbereitungsprozess**
   - Parsing und Chunking der Dokumente (z. B. mit `langchain`/`llamaindex`).
   - Speicherung der Embeddings in einer lokalen Vektor-Datenbank (Faiss, Qdrant oder Chroma), ohne Cloud-Dienste.
   - Versionierung der Datenpipelines (Git) sowie periodische Re-Indexierung.

3. **Datensicherheit**
   - Importprozesse laufen ausschließlich auf dem verschlüsselten System.
   - Daten in Ruhe durch LUKS geschützt, im Betrieb zusätzliche Verschlüsselung (z. B. TLS für interne API-Aufrufe).
   - Zugriff auf Trainings- oder Kontextdaten ausschließlich nach RBAC-Berechtigung.

## Netzwerkkonzept und Isolation
1. **Perimeter-Schutz**
   - Physisch getrenntes Netzwerksegment (VLAN) für den LLM-Server.
   - Firewall-Only-Outbound-Regeln: Standardmäßig kein Internetzugang; whitelisting einzelner Update-Spiegel falls unbedingt nötig.

2. **Air-Gap / Daten-Diode Verfahren**
   - Für Updates und Modellimporte Nutzung eines geprüften Jump-Hosts mit Malware-Scanning.
   - Transfer via signierter Offline-Medien (USB mit Hardware-Write-Protection).

3. **Monitoring**
   - Intrusion Detection (z. B. Zeek, Suricata) im internen Segment.
   - Regelmäßige Log-Analysen und Integritätsprüfungen (AIDE, Tripwire).

## Absicherung der Modellintegrität
1. **Modellbeschaffung**
   - Download aus vertrauenswürdigen Quellen mit verifizierbaren Signaturen/Checksums.
   - Verwendung von reproducible builds, sofern verfügbar.

2. **Versionsmanagement**
   - Lokales Artefakt-Repository für Modelle und Tokenizer (z. B. Git LFS, MinIO).
   - Freigabeprozess mit Vier-Augen-Prinzip für neue Modellversionen.

3. **Runtime-Isolation**
   - Modelle in separaten Containern/VMs mit minimalen Berechtigungen ausführen.
   - Keine ausgehenden Verbindungen aus den Modelldiensten; Netzwerk-Namespace-Isolation.

4. **Integritätsprüfungen**
   - Hashing der Modellgewichte bei jedem Start; Abgleich mit referenzierten Checksums.
   - Regelmäßige Security-Scans der Container-Images (Trivy, Grype).

## Einsatzszenarien und Grenzen
1. **Primäre Einsatzzwecke**
   - Unterstützung bei Recherche, Wissensmanagement, Zusammenfassung interner Dokumente.
   - Beantwortung interner Richtlinien- oder Prozessfragen.
   - Klassifikation oder Analyse von Texten mit Fokus auf Compliance und Qualitätssicherung.

2. **Bewusst ausgeschlossene Einsätze**
   - **Kein Coding-Assistant**: minimiert Risiko unerkannter Backdoors in generiertem Code.
   - Keine offene Schnittstelle für externe Nutzer oder Automatisierungs-Tools ohne menschliche Kontrolle.

3. **Evaluierung**
   - Regelmäßige Reviews (z. B. vierteljährlich) zur Überprüfung, ob neue Anwendungsfälle hinzukommen sollen.
   - Dokumentierte Risikoanalysen für jeden neuen Use-Case.

## Betrieb und Wartung
1. **Patch-Management**
   - Offline-Repository für Ubuntu-Pakete; Updates nach getestetem Change-Management-Prozess.
   - Security Bulletins bewerten, relevante Patches im Testsystem verifizieren.

2. **Backup-Strategie**
   - Verschlüsselte, versionierte Backups (BorgBackup, restic) auf separatem Medium.
   - Regelmäßige Recovery-Tests.

3. **Notfall- und Incident-Response**
   - Definierte SOPs für Verdachtsfälle (Isolation, Forensik, Wiederherstellung).
   - Schulung des Betriebspersonals.

## Zusammenfassung
Das Konzept kombiniert ein gehärtetes, vollständig verschlüsseltes Ubuntu-System mit strikt kontrollierter Netzwerkumgebung, dedizierten Prozessen zur Datenbefüllung und umfangreichen Maßnahmen zur Sicherstellung der Modellintegrität. Durch bewusste Einschränkung der Nutzung auf Wissens- und Analysezwecke werden Angriffsszenarien, wie sie im Coding-Assistance-Kontext auftreten könnten, reduziert.
