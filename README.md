# Teddy Lambda - Sistema de Timestamps

Sistema serverless que grava timestamps no DynamoDB a cada 5 minutos usando AWS Lambda, gerenciado via Terraform e CI/CD com GitHub Actions.

## Arquitetura

O sistema é composto por:

- **AWS Lambda Function**: Executa a cada 5 minutos via EventBridge, grava timestamp no DynamoDB
- **DynamoDB Table**: Armazena os timestamps com chave primária `id`
- **EventBridge Rule**: Dispara a Lambda a cada 5 minutos
- **SQS DLQ**: Fila de mensagens mortas para tratamento de erros
- **IAM Roles/Policies**: Permissões necessárias para a Lambda acessar DynamoDB, CloudWatch e SQS
- **CloudWatch Metrics**: Métricas de sucesso, erros e duração das execuções

## Fluxo de Funcionamento

1. EventBridge dispara a Lambda a cada 5 minutos
2. Lambda gera um timestamp UTC e um ID único
3. Lambda grava o registro no DynamoDB com retry automático
4. Lambda envia métricas para CloudWatch (sucesso, erros, duração)
5. Em caso de falha após retries, mensagem é enviada para DLQ

## Estrutura do Projeto

```
teddy-lambda/
├── lambda/
│   └── lambda_function.py
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── backend.tf.example
├── scripts/
│   └── setup-terraform-backend.sh
└── .github/workflows/
    └── terraform.yml
```

## Componentes

### Lambda Function (`lambda/lambda_function.py`)

Função Python que:
- Gera timestamp UTC e ID único
- Grava no DynamoDB com retry exponencial em caso de throttling
- Envia métricas para CloudWatch (RecordsWritten, LambdaDuration, LambdaSuccess, LambdaErrors)
- Trata erros e envia para DLQ se necessário

### Terraform (`terraform/`)

Infraestrutura como código que cria:
- Tabela DynamoDB (PAY_PER_REQUEST)
- Lambda Function com código Python
- EventBridge Rule (execução a cada 5 minutos)
- IAM Role e Policies
- SQS Dead Letter Queue
- CloudWatch Event Target e Lambda Permission

### CI/CD (`.github/workflows/terraform.yml`)

Pipeline automatizado que:
- Valida e formata código Terraform
- Executa `terraform plan` em Pull Requests
- Executa `terraform apply` em push para main/master
- Executa `terraform destroy` quando PR é fechado sem merge
- Importa recursos existentes automaticamente antes de aplicar/destruir

## Configuração

### Secrets do GitHub Actions

Configure em **Settings → Secrets and variables → Actions**:

- `AWS_ACCESS_KEY_ID`: Chave de acesso AWS
- `AWS_SECRET_ACCESS_KEY`: Chave secreta AWS
- `TERRAFORM_STATE_BUCKET`: Bucket S3 para estado do Terraform (opcional)
- `TERRAFORM_STATE_DYNAMODB_TABLE`: Tabela DynamoDB para locking (opcional)

### Execução Local

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

## Variáveis do Terraform

- `region`: Região AWS (default: `us-east-1`)
- `project_name`: Prefixo dos recursos (default: `teddy`)
- `table_name`: Nome da tabela DynamoDB (default: `teddy-timestamps`)
- `lambda_runtime`: Runtime da Lambda (default: `python3.10`)

## Outputs

- `dynamodb_table_name`: Nome da tabela DynamoDB
- `lambda_function_name`: Nome da função Lambda
- `event_rule_name`: Nome da regra do EventBridge
