import json
import os
import time
import uuid
from datetime import datetime, timezone

import boto3
from botocore.exceptions import ClientError

TABLE_NAME = os.environ.get("TABLE_NAME")
MAX_RETRIES = int(os.environ.get("MAX_RETRIES", "3"))
RETRY_DELAY = float(os.environ.get("RETRY_DELAY", "1.0"))

dynamodb = boto3.resource("dynamodb")
cloudwatch = boto3.client("cloudwatch")
table = dynamodb.Table(TABLE_NAME)


def put_item_with_retry(item, max_retries=MAX_RETRIES, retry_delay=RETRY_DELAY):
    for attempt in range(max_retries):
        try:
            table.put_item(Item=item)
            return True
        except ClientError as e:
            error_code = e.response.get("Error", {}).get("Code", "")
            if error_code in [
                "ProvisionedThroughputExceededException",
                "ThrottlingException",
            ]:
                if attempt < max_retries - 1:
                    wait_time = retry_delay * (2 ** attempt)
                    print(f"[RETRY] Tentativa {attempt + 1}/{max_retries} após {wait_time}s - {error_code}")
                    time.sleep(wait_time)
                    continue
            raise e
    return False


def put_metric(metric_name, value, unit="Count"):
    try:
        cloudwatch.put_metric_data(
            Namespace="Lambda/TimestampWriter",
            MetricData=[
                {
                    "MetricName": metric_name,
                    "Value": value,
                    "Unit": unit,
                    "Timestamp": datetime.now(timezone.utc),
                }
            ],
        )
    except Exception as e:
        print(f"[WARNING] Falha ao enviar métrica: {e}")


def lambda_handler(event, context):
    start_time = time.time()
    now = datetime.now(timezone.utc).isoformat()
    record_id = f"{now}-{uuid.uuid4().hex[:8]}"

    item = {"id": record_id, "horario": now}

    try:
        success = put_item_with_retry(item)
        if success:
            duration = time.time() - start_time
            print(f"[SUCESSO] Timestamp {now} gravado na tabela {TABLE_NAME}")
            put_metric("RecordsWritten", 1)
            put_metric("LambdaDuration", duration, "Seconds")
            put_metric("LambdaSuccess", 1)

            return {
                "statusCode": 200,
                "body": json.dumps(
                    {
                        "message": "Registro gravado com sucesso!",
                        "timestamp": now,
                        "record_id": record_id,
                        "duration": duration,
                    }
                ),
            }
    except Exception as e:
        duration = time.time() - start_time
        print(f"[ERRO] Falha ao gravar no DynamoDB: {e}")
        put_metric("LambdaErrors", 1)
        put_metric("LambdaDuration", duration, "Seconds")
        put_metric("LambdaSuccess", 0)
        raise e