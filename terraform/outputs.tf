output "dynamodb_table_name" {
  value = aws_dynamodb_table.timestamps.name
}

output "lambda_function_name" {
  value = aws_lambda_function.timestamp_writer.function_name
}

output "event_rule_name" {
  value = aws_cloudwatch_event_rule.every_5_minutes.name
}