#!/bin/bash
#
# IMDSpoof Honeypot - Quick Deployment Script
# Dieses Skript hilft beim schnellen Deployment des CloudFormation Stacks
#

set -e

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================"
echo "IMDSpoof Honeypot - Quick Deployment"
echo "========================================"
echo ""

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI ist nicht installiert${NC}"
    echo "Installieren Sie AWS CLI: https://aws.amazon.com/cli/"
    exit 1
fi

# Check jq (optional, aber hilfreich)
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}Warnung: jq ist nicht installiert (optional, aber empfohlen)${NC}"
fi

# AWS Region
read -p "AWS Region (default: eu-central-1): " AWS_REGION
AWS_REGION=${AWS_REGION:-eu-central-1}
export AWS_DEFAULT_REGION=$AWS_REGION

echo ""
echo -e "${GREEN}[1/6] Prüfe AWS-Zugriff...${NC}"
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: Keine AWS-Berechtigung. Konfigurieren Sie aws configure${NC}"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Account ID: $ACCOUNT_ID"
echo ""

# Default VPC ermitteln
echo -e "${GREEN}[2/6] Ermittle Standard-VPC...${NC}"
DEFAULT_VPC=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "")

if [ -z "$DEFAULT_VPC" ] || [ "$DEFAULT_VPC" == "None" ]; then
    echo -e "${YELLOW}Keine Standard-VPC gefunden.${NC}"
    read -p "VPC ID eingeben: " VPC_ID
else
    echo "Standard-VPC gefunden: $DEFAULT_VPC"
    read -p "VPC ID verwenden (default: $DEFAULT_VPC): " VPC_ID
    VPC_ID=${VPC_ID:-$DEFAULT_VPC}
fi

# Erstes Subnet in der VPC ermitteln
echo ""
echo -e "${GREEN}[3/6] Ermittle Subnet...${NC}"
DEFAULT_SUBNET=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[0].SubnetId' --output text 2>/dev/null || echo "")

if [ -z "$DEFAULT_SUBNET" ] || [ "$DEFAULT_SUBNET" == "None" ]; then
    echo -e "${YELLOW}Kein Subnet gefunden.${NC}"
    read -p "Subnet ID eingeben: " SUBNET_ID
else
    echo "Subnet gefunden: $DEFAULT_SUBNET"
    read -p "Subnet ID verwenden (default: $DEFAULT_SUBNET): " SUBNET_ID
    SUBNET_ID=${SUBNET_ID:-$DEFAULT_SUBNET}
fi

# Canary Token Credentials
echo ""
echo -e "${GREEN}[4/6] Canary Token Credentials eingeben...${NC}"
echo -e "${YELLOW}Hinweis: Erstellen Sie Ihren Canary Token auf https://canarytokens.org/generate#${NC}"
echo ""

read -p "Canary Access Key ID (AKIA...): " CANARY_ACCESS_KEY
if [ -z "$CANARY_ACCESS_KEY" ]; then
    echo -e "${RED}Error: Access Key ID ist erforderlich${NC}"
    exit 1
fi

read -sp "Canary Secret Access Key: " CANARY_SECRET_KEY
echo ""
if [ -z "$CANARY_SECRET_KEY" ]; then
    echo -e "${RED}Error: Secret Access Key ist erforderlich${NC}"
    exit 1
fi

read -p "Canary Session Token (Enter für default): " CANARY_TOKEN
if [ -z "$CANARY_TOKEN" ]; then
    CANARY_TOKEN="IQoJb3Jpz2cXpQRkpVX3Uf////////////xMdLZHNjbmtGZ2NhL//////////wPbEVN6UGVwIgJ7I5bAOpTzLKpWxIb7sZR74Dq9MNYW/3kThIUWKqDNCoZP+iSbXHHTZuSILnIlFfnT+QcPnlS/tOzaGPxwhuFFnhpMKVtQqgfhWtdMFUPbUPxbtIIhVqPpueagIfbsAjbRRCvrLkRylooW+JDmiqymJQzeReoiWqCnSgzyvYnsSVZRHeNANqYFq/aMqTJ/KvXlbtbzjTPNHahpZXGamgvAtniqkJqhBYGPGQaGKi+cPqqEZdYIYPzMaYjtJgNtGmBoDxkKQeKRVlEtpkAdWMjXXWYm+BnddxxrNAnBcNwrjBtSp/OpQdjvhFfahhKxyEDinpjDkkRrfWTdkmwaMmOjDBHbtUotMJPekH+KtArZuX+HsSAoNfZlwHhnvFTC+jFqgwXelfAfOhrDxlEvadqCAGLOVKLBBtQjFwrXkDmHccVVdUZZEkzQqLuYRlMWVgUpJZQroHHK/uEBiYRYKrpdkEhcWwYPRkPagFLYzdWRTnhxtHGoNNTyq/EHBOKog+rtYUH+QJ+MBYf/ALKSUzIzij/WNH/bNfkVpqPdYPMYtmfk/CBpXoDgj+VweJZJGzHdXP/zBlvqvmHaswckLfSVWtoNLspdlNJUua+JMy/QxlEeghQiNPMmixPv+Ofn/IpLsHmhFYRceGt+EcVKKayGicwSiUXPFG/JafLNLNwQjMVbMb+WGm/CMsYfnNengS/XYYh/hRXNnSQzzcmscXjouqKhzmWhc/HGc+/wNRmrtFVwhTldmFAxiqmScziGDFvxlXeoEThIqKoVBqeqLiWNBeDzjKlwfVbiyFtQfrXWFwzVvTtJ+rDjLPk+SVgapQVRwpGlAUtjEkbuLyCYqLeO/uqGhKJhMZKjNTQ/aVPXkWR/CGxTmLWuEMZQFuSWlIFqYvyyfPHWQPCWDPwnjkGkkjNrJUhfkOXNpHAnBNHYpXUMidzsggFUccMzJIuqVLGAKgUENdRxsqqJiR+FbOgpnjaKEzyqWcLjiGDxMVpIdNqyWuJniNCRqyFKLkDsCi+MejhGVMVSr"
fi

# Stack Name
echo ""
read -p "Stack Name (default: imdspoof-workshop-$USER): " STACK_NAME
STACK_NAME=${STACK_NAME:-imdspoof-workshop-$USER}

# Zusammenfassung
echo ""
echo -e "${GREEN}[5/6] Deployment-Zusammenfassung:${NC}"
echo "-----------------------------------"
echo "Region:       $AWS_REGION"
echo "VPC ID:       $VPC_ID"
echo "Subnet ID:    $SUBNET_ID"
echo "Stack Name:   $STACK_NAME"
echo "Access Key:   ${CANARY_ACCESS_KEY:0:10}..."
echo "-----------------------------------"
echo ""

read -p "Mit diesem Setup fortfahren? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Deployment abgebrochen."
    exit 0
fi

# CloudFormation Stack erstellen
echo ""
echo -e "${GREEN}[6/6] Deploying CloudFormation Stack...${NC}"
echo "Dies dauert ca. 3-5 Minuten..."
echo ""

aws cloudformation create-stack \
    --stack-name "$STACK_NAME" \
    --template-body file://imdspoof-honeypot.yaml \
    --parameters \
        ParameterKey=AWSAccessKeyId,ParameterValue="$CANARY_ACCESS_KEY" \
        ParameterKey=AWSSecretAccessKey,ParameterValue="$CANARY_SECRET_KEY" \
        ParameterKey=AWSSessionToken,ParameterValue="$CANARY_TOKEN" \
        ParameterKey=VpcId,ParameterValue="$VPC_ID" \
        ParameterKey=SubnetId,ParameterValue="$SUBNET_ID" \
    --capabilities CAPABILITY_NAMED_IAM \
    --region "$AWS_REGION"

echo ""
echo -e "${YELLOW}Stack wird erstellt... Warte auf Completion...${NC}"
echo ""

# Warten auf Stack Completion
aws cloudformation wait stack-create-complete \
    --stack-name "$STACK_NAME" \
    --region "$AWS_REGION"

# Stack Outputs anzeigen
echo ""
echo -e "${GREEN}✓ Stack erfolgreich erstellt!${NC}"
echo ""
echo "========================================"
echo "Stack Outputs:"
echo "========================================"

INSTANCE_ID=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[?OutputKey==`InstanceId`].OutputValue' \
    --output text \
    --region "$AWS_REGION")

SSM_COMMAND=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[?OutputKey==`SessionManagerCommand`].OutputValue' \
    --output text \
    --region "$AWS_REGION")

echo "Instance ID: $INSTANCE_ID"
echo ""
echo "Session Manager Connect:"
echo "$SSM_COMMAND"
echo ""
echo "Oder via AWS Console:"
echo "https://console.aws.amazon.com/systems-manager/session-manager/$INSTANCE_ID?region=$AWS_REGION"
echo ""
echo -e "${GREEN}Testen Sie den Honeypot:${NC}"
echo "1. Verbinden Sie sich via Session Manager"
echo "2. Führen Sie aus: curl http://169.254.169.254/latest/meta-data/iam/security-credentials/ec2-admin"
echo "3. Prüfen Sie Ihre E-Mail für Canary Token Alerts!"
echo ""
echo -e "${YELLOW}Cleanup nach dem Workshop:${NC}"
echo "aws cloudformation delete-stack --stack-name $STACK_NAME --region $AWS_REGION"
echo ""
