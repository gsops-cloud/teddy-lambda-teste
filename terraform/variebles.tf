variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix used for resource names"
  type        = string
  default     = "teddy"
}

variable "table_name" {
  description = "DynamoDB table name"
  type        = string
  default     = "teddy-timestamps"
}

variable "lambda_zip_filename" {
  description = "Filename of the lambda zip in this module path"
  type        = string
  default     = "lambda.zip"
}

variable "lambda_runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "python3.10"
}

variable "aws_profile" {
  description = "AWS CLI profile name (opcional)"
  type        = string
  default     = null
  nullable    = true
}

variable "aws_access_key_id" {
  description = "AWS access key (opcional, não recomendado em VCS)"
  type        = string
  default     = null
  sensitive   = true
  nullable    = true
}

variable "aws_secret_access_key" {
  description = "AWS secret key (opcional, não recomendado em VCS)"
  type        = string
  default     = null
  sensitive   = true
  nullable    = true
}

variable "aws_session_token" {
  description = "AWS session token (opcional)"
  type        = string
  default     = null
  sensitive   = true
  nullable    = true
}

variable "terraform_backend_bucket" {
  description = "Nome do bucket S3 para armazenar o estado do Terraform (opcional)"
  type        = string
  default     = null
  nullable    = true
}

variable "terraform_backend_key" {
  description = "Chave do objeto no S3 para o estado do Terraform"
  type        = string
  default     = "terraform.tfstate"
}

variable "terraform_backend_dynamodb_table" {
  description = "Nome da tabela DynamoDB para locking do estado (opcional)"
  type        = string
  default     = null
  nullable    = true
}