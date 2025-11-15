#!/bin/bash
#
# IMDSpoof Honeypot - Cleanup Script
# Dieses Skript löscht den CloudFormation Stack nach dem Workshop
#

set -e

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================"
echo "IMDSpoof Honeypot - Cleanup"
echo "========================================"
echo ""

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI ist nicht installiert${NC}"
    exit 1
fi

# AWS Region
read -p "AWS Region (default: eu-central-1): " AWS_REGION
AWS_REGION=${AWS_REGION:-eu-central-1}
export AWS_DEFAULT_REGION=$AWS_REGION

# Alle IMDSpoof Stacks in der Region auflisten
echo ""
echo -e "${GREEN}Suche nach IMDSpoof Stacks in Region $AWS_REGION...${NC}"
echo ""

STACKS=$(aws cloudformation list-stacks \
    --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
    --query 'StackSummaries[?contains(StackName, `imdspoof`)].StackName' \
    --output text \
    --region "$AWS_REGION" 2>/dev/null || echo "")

if [ -z "$STACKS" ]; then
    echo -e "${YELLOW}Keine IMDSpoof Stacks gefunden in Region $AWS_REGION${NC}"
    echo ""
    read -p "Stack Name manuell eingeben: " STACK_NAME
    if [ -z "$STACK_NAME" ]; then
        echo "Abgebrochen."
        exit 0
    fi
else
    echo "Gefundene Stacks:"
    echo "-----------------------------------"
    i=1
    STACK_ARRAY=($STACKS)
    for stack in "${STACK_ARRAY[@]}"; do
        echo "$i) $stack"
        ((i++))
    done
    echo "-----------------------------------"
    echo ""

    read -p "Stack Nummer zum Löschen (oder Stack Name): " SELECTION

    if [[ "$SELECTION" =~ ^[0-9]+$ ]]; then
        # Nummer eingegeben
        idx=$((SELECTION - 1))
        STACK_NAME="${STACK_ARRAY[$idx]}"
    else
        # Stack Name eingegeben
        STACK_NAME="$SELECTION"
    fi
fi

if [ -z "$STACK_NAME" ]; then
    echo -e "${RED}Error: Kein Stack ausgewählt${NC}"
    exit 1
fi

# Stack Details anzeigen
echo ""
echo -e "${GREEN}Stack Details für: $STACK_NAME${NC}"
echo "-----------------------------------"

INSTANCE_ID=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[?OutputKey==`InstanceId`].OutputValue' \
    --output text \
    --region "$AWS_REGION" 2>/dev/null || echo "N/A")

CREATION_TIME=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].CreationTime' \
    --output text \
    --region "$AWS_REGION" 2>/dev/null || echo "N/A")

echo "Stack Name:    $STACK_NAME"
echo "Instance ID:   $INSTANCE_ID"
echo "Created:       $CREATION_TIME"
echo "Region:        $AWS_REGION"
echo "-----------------------------------"
echo ""

# Bestätigung
echo -e "${YELLOW}WARNUNG: Diese Aktion kann nicht rückgängig gemacht werden!${NC}"
read -p "Stack '$STACK_NAME' wirklich löschen? (y/n): " CONFIRM

if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Cleanup abgebrochen."
    exit 0
fi

# Stack löschen
echo ""
echo -e "${GREEN}Lösche CloudFormation Stack...${NC}"

aws cloudformation delete-stack \
    --stack-name "$STACK_NAME" \
    --region "$AWS_REGION"

echo ""
echo -e "${YELLOW}Stack wird gelöscht... Warte auf Completion...${NC}"
echo "Dies kann einige Minuten dauern..."
echo ""

# Warten auf Stack Deletion
if aws cloudformation wait stack-delete-complete \
    --stack-name "$STACK_NAME" \
    --region "$AWS_REGION" 2>/dev/null; then
    echo ""
    echo -e "${GREEN}✓ Stack erfolgreich gelöscht!${NC}"
    echo ""
    echo "Ressourcen wurden entfernt:"
    echo "  - EC2 Instance ($INSTANCE_ID)"
    echo "  - IAM Role & Instance Profile"
    echo "  - Security Group"
    echo ""
else
    echo ""
    echo -e "${YELLOW}Stack Deletion wurde initiiert${NC}"
    echo "Prüfen Sie den Status in der CloudFormation Console:"
    echo "https://console.aws.amazon.com/cloudformation/home?region=$AWS_REGION"
    echo ""
fi

echo -e "${GREEN}Cleanup abgeschlossen!${NC}"
echo ""
