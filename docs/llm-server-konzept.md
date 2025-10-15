# Konzept: Lokal betriebener LLM-Server auf Ubuntu mit LUKS-Verschlüsselung

## Zielsetzung und Rahmenbedingungen
- Bereitstellung eines lokalen LLM-Servers auf einem gehärteten Ubuntu-System.
- Speicherung sensibler Daten auf vollständig verschlüsselten Datenträgern (LUKS-basiert).
- Strikte Netzwerkkontrolle: Betrieb im Offline-Modus bzw. nur über dedizierte, freigegebene Verbindungen.
- Fokus auf interne Wissensabfrage, Dokumentenanalyse und Entscheidungsunterstützung; kein Coding-Assistant-Einsatz.

## Infrastruktur und Software-Stack
1. **Basisbetriebssystem**
   - Ubuntu Server LTS, minimales Installationsprofil ohne zusätzliche Desktop-Komponenten.
   - Vollständige Festplattenverschlüsselung mittels LUKS2 (dm-crypt) mit TPM-gestützter Schlüsselverwaltung oder manuellem Passphrase-Entry beim Boot.

2. **Virtualisierung / Containerisierung (optional)**
   - Einsatz von Proxmox oder VMware ESXi bei Bedarf an Multi-VM-Umgebung.
   - Für Containerisierung: Docker oder Podman mit rootless-Konfiguration; bevorzugt Podman wegen geringerer Angriffsfläche.

3. **LLM-Serving-Schicht**
   - Einsatz von Open-Source-Frameworks wie `text-generation-inference`, `llama.cpp` oder `vLLM`.
   - GPU-Unterstützung (CUDA / ROCm) je nach Hardware; fallback auf CPU für kleinere Modelle.
   - Reverse-Proxy (nginx oder Traefik) ausschließlich für interne Clients im Intranet.

4. **Zugriffskontrolle und Authentifizierung**
   - Zentrale Authentifizierung über Keycloak oder OpenID Connect Provider.
   - Role-Based Access Control (RBAC) für differenzierte Zugriffsstufen (Admin, Modell-Operator, Nutzer).
   - Audit-Logging (z. B. mit Loki + Grafana) für nachvollziehbare Nutzungshistorie.

5. **Systemhärtung**
   - Deaktivieren nicht benötigter Dienste, `ufw`/`nftables` strikt konfigurieren.
   - Automatisierte Konfigurationsverwaltung via Ansible; Dokumentation aller Änderungen (Infrastructure as Code).

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
