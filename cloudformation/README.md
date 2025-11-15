# IMDSpoof Honeypot - Workshop Deployment Guide

Dieses CloudFormation Template automatisiert das Deployment eines IMDSpoof Honeypots für Security-Workshop-Teilnehmer.

## Überblick

Das Template erstellt:
- **EC2 Instance** (t3.micro, Amazon Linux 2023, Free Tier eligible)
- **IAM Role** mit Session Manager Zugriff (kein SSH erforderlich)
- **Security Group** ohne SSH-Port (nur HTTPS outbound für SSM)
- **Automatische Installation** von IMDSpoof mit Ihren Canary Token Credentials

## Voraussetzungen

### 1. Canary Token erstellen

Besuchen Sie [CanaryTokens.org](https://canarytokens.org/generate#):

1. Wählen Sie **"AWS Keys"** als Token-Typ
2. Geben Sie Ihre E-Mail-Adresse ein (für Alerts)
3. Notiz: z.B. "IMDSpoof Workshop - [Ihr Name]"
4. Klicken Sie auf **"Create my Canarytoken"**
5. Notieren Sie sich:
   ```
   aws_access_key_id = AKIA...
   aws_secret_access_key = uZF0y/l5X...
   ```

### 2. AWS Voraussetzungen

- AWS Account mit Berechtigungen für EC2, IAM, VPC
- AWS CLI installiert (optional, für Session Manager)
- VPC mit mindestens einem Subnet (default VPC ist ausreichend)

## Deployment via AWS Console

### Schritt 1: CloudFormation Stack erstellen

1. Öffnen Sie die [AWS CloudFormation Console](https://console.aws.amazon.com/cloudformation/)
2. Klicken Sie auf **"Create stack"** → **"With new resources (standard)"**
3. Wählen Sie **"Upload a template file"**
4. Laden Sie `imdspoof-honeypot.yaml` hoch
5. Klicken Sie auf **"Next"**

### Schritt 2: Stack-Details konfigurieren

**Stack Name:** `imdspoof-workshop-[IhrName]` (z.B. `imdspoof-workshop-mueller`)

**AWS Credentials Configuration:**
- **AWSAccessKeyId**: Fügen Sie Ihren `aws_access_key_id` ein (z.B. `AKIA...`)
- **AWSSecretAccessKey**: Fügen Sie Ihren `aws_secret_access_key` ein
- **AWSSessionToken**: Lassen Sie den Default-Wert (oder fügen Sie einen eigenen ein)

**Network Configuration:**
- **VpcId**: Wählen Sie Ihre VPC (normalerweise die default VPC)
- **SubnetId**: Wählen Sie ein öffentliches Subnet

Klicken Sie auf **"Next"**

### Schritt 3: Stack-Optionen (Optional)

- Lassen Sie alles auf Default
- Klicken Sie auf **"Next"**

### Schritt 4: Review und Create

1. Überprüfen Sie Ihre Eingaben
2. ✅ Aktivieren Sie **"I acknowledge that AWS CloudFormation might create IAM resources"**
3. Klicken Sie auf **"Submit"**

### Schritt 5: Warten auf Completion

- Status wechselt von `CREATE_IN_PROGRESS` → `CREATE_COMPLETE` (ca. 3-5 Minuten)
- Bei Problemen: Prüfen Sie den "Events"-Tab für Fehlermeldungen

## Deployment via AWS CLI

```bash
# 1. Parameter-Datei erstellen (parameters.json)
cat > parameters.json << 'EOF'
[
  {
    "ParameterKey": "AWSAccessKeyId",
    "ParameterValue": "AKIA..."
  },
  {
    "ParameterKey": "AWSSecretAccessKey",
    "ParameterValue": "uZF0y/l5X..."
  },
  {
    "ParameterKey": "VpcId",
    "ParameterValue": "vpc-xxxxx"
  },
  {
    "ParameterKey": "SubnetId",
    "ParameterValue": "subnet-xxxxx"
  }
]
EOF

# 2. Stack deployen
aws cloudformation create-stack \
  --stack-name imdspoof-workshop-mueller \
  --template-body file://imdspoof-honeypot.yaml \
  --parameters file://parameters.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --region eu-central-1

# 3. Status überwachen
aws cloudformation wait stack-create-complete \
  --stack-name imdspoof-workshop-mueller \
  --region eu-central-1

# 4. Outputs anzeigen
aws cloudformation describe-stacks \
  --stack-name imdspoof-workshop-mueller \
  --region eu-central-1 \
  --query 'Stacks[0].Outputs'
```

## Zugriff auf die Honeypot-Instance

### Via AWS Console (Session Manager)

1. Öffnen Sie die [EC2 Console](https://console.aws.amazon.com/ec2/)
2. Klicken Sie auf **"Instances"**
3. Wählen Sie die Instance mit dem Namen `IMDSpoof-Honeypot-[StackName]`
4. Klicken Sie auf **"Connect"** → **"Session Manager"** → **"Connect"**

### Via AWS CLI (Session Manager)

```bash
# Instance ID aus Stack Outputs holen
INSTANCE_ID=$(aws cloudformation describe-stacks \
  --stack-name imdspoof-workshop-mueller \
  --query 'Stacks[0].Outputs[?OutputKey==`InstanceId`].OutputValue' \
  --output text)

# Session starten
aws ssm start-session --target $INSTANCE_ID --region eu-central-1
```

## Honeypot testen

Sobald Sie mit der Instance verbunden sind:

```bash
# 1. Service Status prüfen
sudo systemctl status IMDS.service

# 2. IMDS-Endpoint testen
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/ec2-admin

# Erwartete Ausgabe (mit Ihren Canary Token Credentials):
# {
#   "Code": "Success",
#   "Message": "The request was successfully processed.",
#   "LastUpdated": "2024-01-15T10:30:00Z",
#   "Type": "AWS-HMAC",
#   "AccessKeyId": "AKIA...",
#   "SecretAccessKey": "uZF0y/l5X...",
#   "Token": "...",
#   "Expiration": "2024-01-15T16:30:00Z"
# }
```

## Installation-Logs prüfen

```bash
# Vollständiges Setup-Log anzeigen
sudo cat /var/log/imdspoof-setup.log

# Service-Logs anzeigen
sudo journalctl -u IMDS.service -f
```

## Simulieren eines Angriffs

```bash
# Auf der Honeypot-Instance:
# 1. Credentials abrufen (simuliert Angreifer)
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/ec2-admin | jq .

# 2. Versuchen Sie, die Credentials zu verwenden (simuliert Exfiltration)
export AWS_ACCESS_KEY_ID="<AccessKeyId aus Curl-Ausgabe>"
export AWS_SECRET_ACCESS_KEY="<SecretAccessKey aus Curl-Ausgabe>"
aws sts get-caller-identity

# 3. Prüfen Sie Ihre E-Mail!
# Sie sollten eine Canary Token Alert-E-Mail erhalten mit:
# - Zeitstempel des Zugriffs
# - IP-Adresse
# - User-Agent
# - AWS-Aktion (z.B. sts:GetCallerIdentity)
```

## Workshop-Szenarien

### Szenario 1: SSRF-Simulation
```bash
# Installieren Sie curl auf der Instance
sudo dnf install -y curl

# Simulieren Sie SSRF-Angriff
curl "http://localhost:54321/latest/meta-data/iam/security-credentials/ec2-admin"
```

### Szenario 2: Privilege Escalation via IMDS
```bash
# Zeigen Sie, wie Angreifer normalerweise IMDS missbrauchen würden
curl http://169.254.169.254/latest/meta-data/
curl http://169.254.169.254/latest/meta-data/iam/
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/ec2-admin
```

## Troubleshooting

### Service läuft nicht
```bash
# Service-Status prüfen
sudo systemctl status IMDS.service

# Service neu starten
sudo systemctl restart IMDS.service

# Logs prüfen
sudo journalctl -u IMDS.service --no-pager
```

### iptables-Regel fehlt
```bash
# iptables-Regel prüfen
sudo iptables -t nat -L OUTPUT -v -n | grep 169.254.169.254

# Manuell hinzufügen (falls nötig)
sudo iptables -t nat -A OUTPUT -p tcp -d 169.254.169.254 --dport 80 -j DNAT --to-destination 127.0.0.1:54321
```

### Endpoint antwortet nicht
```bash
# Binary prüfen
ls -la /bin/IMDS

# Prozess prüfen
ps aux | grep IMDS

# Port prüfen
sudo netstat -tlnp | grep 54321
```

## Cleanup nach dem Workshop

### Via AWS Console

1. Öffnen Sie die [CloudFormation Console](https://console.aws.amazon.com/cloudformation/)
2. Wählen Sie Ihren Stack (`imdspoof-workshop-[IhrName]`)
3. Klicken Sie auf **"Delete"**
4. Bestätigen Sie mit **"Delete stack"**

### Via AWS CLI

```bash
aws cloudformation delete-stack \
  --stack-name imdspoof-workshop-mueller \
  --region eu-central-1

# Warten auf Löschung
aws cloudformation wait stack-delete-complete \
  --stack-name imdspoof-workshop-mueller \
  --region eu-central-1
```

## Kosten

- **t3.micro Instance**: ~$0.0104/Stunde (ca. $0.08 für 8-Stunden-Workshop)
- **Free Tier**: Erste 750 Stunden/Monat kostenlos für t3.micro
- **Session Manager**: Kostenlos
- **Canary Tokens**: Kostenlos

**Geschätzte Workshop-Kosten**: $0.00 - $0.10 (abhängig von Free Tier Status)

## Sicherheitshinweise

⚠️ **WICHTIG:**
- Dieses Tool ist **NUR** für Deception/Honeypot-Zwecke
- Deployen Sie es **NICHT** auf Produktions-Instances
- Löschen Sie Instances nach dem Workshop, um Kosten zu vermeiden
- Die Canary Token Credentials sind **fake** und dienen nur zur Angreifer-Detektion

## Support

Bei Problemen während des Workshops:
1. Prüfen Sie die CloudFormation Events für Deployment-Fehler
2. Prüfen Sie `/var/log/imdspoof-setup.log` auf der Instance
3. Kontaktieren Sie Ihren Workshop-Leiter

## Weitere Ressourcen

- [IMDSpoof GitHub Repository](https://github.com/c0ffee0wl/IMDSpoof)
- [CanaryTokens.org](https://canarytokens.org/)
- [AWS IMDS Documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-metadata.html)
- [IMDS Security Best Practices](https://hackingthe.cloud/aws/exploitation/ec2-metadata-ssrf/)
