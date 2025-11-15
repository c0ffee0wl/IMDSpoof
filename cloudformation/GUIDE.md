# IMDSpoof Workshop 

## Hands-On Deployment

**Schritt 1: Canary Token erstellen (10 Min)**

Lassen Sie Teilnehmer:
1. https://canarytokens.org/generate# öffnen
2. "AWS Keys" auswählen
3. E-Mail eingeben
4. Token speichern

**Schritt 2: CloudFormation Deployment (20 Min)**

Option A - AWS Console (empfohlen für Anfänger):
```
1. CloudFormation Console öffnen
2. "Create stack" → "Upload template"
3. imdspoof-honeypot.yaml hochladen
4. Parameter eingeben
5. Stack erstellen
```

Option B - AWS CLI (für erfahrene Nutzer):
```bash
./deploy.sh
```

**Schritt 3: Verbindung & Test (15 Min)**

```bash
# Session Manager Verbindung
aws ssm start-session --target <INSTANCE_ID>

# Service Status
sudo systemctl status IMDS.service

# IMDS testen
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/ec2-admin
```

### Teil 3: Attack Simulation (45-60 Min)

**Szenario 1: Direkter IMDS-Zugriff**

```bash
# Auf Honeypot-Instance
curl http://169.254.169.254/
curl http://169.254.169.254/latest/meta-data/
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/ec2-admin
```

**Szenario 2: Credential Exfiltration**

```bash
# Credentials in JSON speichern
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/ec2-admin | jq . > creds.json

# Credentials parsen
export AWS_ACCESS_KEY_ID=$(cat creds.json | jq -r '.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(cat creds.json | jq -r '.SecretAccessKey')

# Versuchen, Credentials zu verwenden
aws sts get-caller-identity

# → Jetzt E-Mail prüfen für Canary Alert!
```

**Szenario 3: Verschiedene AWS-Aktionen testen**

```bash
# Verschiedene AWS CLI Befehle mit Honey Credentials
aws s3 ls
aws ec2 describe-instances
aws iam list-users

# Jede Aktion triggert einen Alert!
```

### Teil 4: Detection & Response

**Analyse der Canary Token Alerts:**

Typische Alert-Inhalte:
- Timestamp
- Source IP
- User-Agent
- AWS Service aufgerufen (sts, s3, ec2, etc.)
- Request-Details

**Diskussion:**
1. Wie schnell haben Sie den Alert erhalten?
2. Welche Informationen sind für Incident Response nützlich?
3. Was wären die nächsten Schritte in einem echten Incident?

**Best Practices:**
- IMDS v2 erzwingen (IMDSv2)
- Network Segmentation
- Least Privilege IAM Policies
- Honeypot Deployment-Strategien

### Teil 5: Cleanup & Q&A 

**Cleanup:**

```bash
# Via Skript
./cleanup.sh

# Oder manuell
aws cloudformation delete-stack --stack-name <STACK_NAME>
```

## Troubleshooting

### Problem: Stack Creation Failed

**Ursachen:**
- VPC/Subnet falsch
- Keine IAM-Berechtigungen
- Service Quota erreicht

**Lösung:**
```bash
# CloudFormation Events prüfen
aws cloudformation describe-stack-events --stack-name <STACK_NAME>

# Neustart mit korrigierten Parametern
aws cloudformation delete-stack --stack-name <STACK_NAME>
./deploy.sh
```

### Problem: Service läuft nicht auf Instance

**Ursachen:**
- User Data Script fehlgeschlagen
- Go Compilation-Fehler
- iptables-Fehler

**Lösung:**
```bash
# Via Session Manager verbinden
aws ssm start-session --target <INSTANCE_ID>

# Setup-Log prüfen
sudo cat /var/log/imdspoof-setup.log

# Service manuell starten
sudo systemctl restart IMDS.service
sudo systemctl status IMDS.service
```

### Problem: Session Manager funktioniert nicht

**Ursachen:**
- Kein SSM Agent (sollte bei Amazon Linux 2023 vorinstalliert sein)
- Kein Outbound HTTPS in Security Group
- IAM Role fehlt

**Lösung:**
```bash
# Instance Status prüfen
aws ssm describe-instance-information --instance-information-filter-list "key=InstanceIds,valueSet=<INSTANCE_ID>"

# Security Group prüfen
aws ec2 describe-security-groups --group-ids <SG_ID>

# IAM Instance Profile prüfen
aws ec2 describe-instances --instance-ids <INSTANCE_ID> --query 'Reservations[0].Instances[0].IamInstanceProfile'
```

### Problem: Keine Canary Token Alerts

**Ursachen:**
- E-Mail in Spam
- Falsche Credentials in IMDS.go
- AWS CLI nicht korrekt konfiguriert

**Lösung:**
```bash
# Auf Instance: IMDS.go prüfen
sudo cat /opt/IMDSpoof/IMDS.go | grep -A 3 "var accessKey"

# Sollte Ihre Canary Credentials zeigen, nicht "HoneyToken"

# Credentials erneut testen
aws sts get-caller-identity
# Sollte einen Fehler geben UND einen Alert senden
```
