#!/bin/bash
# Script para configurar o backend do Terraform
# Cria a tabela DynamoDB para locking do estado

set -e

REGION="${AWS_REGION:-us-east-1}"
TABLE_NAME="${TERRAFORM_STATE_DYNAMODB_TABLE:-terraform-state-lock-teddy}"
BUCKET_NAME="${TERRAFORM_STATE_BUCKET:-gsopscloud-terraform-teddy}"

echo "🔧 Configurando backend do Terraform..."
echo "Region: $REGION"
echo "DynamoDB Table: $TABLE_NAME"
echo "S3 Bucket: $BUCKET_NAME"
echo ""

# Verifica se a tabela já existe
if aws dynamodb describe-table --table-name "$TABLE_NAME" --region "$REGION" > /dev/null 2>&1; then
    echo "✅ Tabela DynamoDB '$TABLE_NAME' já existe"
else
    echo "📦 Criando tabela DynamoDB '$TABLE_NAME'..."
    aws dynamodb create-table \
        --table-name "$TABLE_NAME" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "$REGION" \
        --tags Key=Name,Value=TerraformStateLock Key=Project,Value=teddy
    
    echo "⏳ Aguardando tabela ficar ativa..."
    aws dynamodb wait table-exists --table-name "$TABLE_NAME" --region "$REGION"
    echo "✅ Tabela DynamoDB criada com sucesso!"
fi

# Verifica se o bucket existe
if aws s3 ls "s3://$BUCKET_NAME" > /dev/null 2>&1; then
    echo "✅ Bucket S3 '$BUCKET_NAME' existe"
else
    echo "⚠️  Bucket S3 '$BUCKET_NAME' não encontrado. Certifique-se de que ele foi criado."
fi

echo ""
echo "✅ Configuração do backend concluída!"
echo ""
echo "📝 Próximos passos:"
echo "1. Configure os seguintes secrets no GitHub Actions:"
echo "   - TERRAFORM_STATE_BUCKET = $BUCKET_NAME"
echo "   - TERRAFORM_STATE_DYNAMODB_TABLE = $TABLE_NAME"
echo ""
echo "2. O pipeline do GitHub Actions usará automaticamente o backend S3"