import json
import os
import boto3
import requests
from datetime import datetime, timedelta

FIREHOSE_NAME = os.environ["FIREHOSE_NAME"]
API_KEY = os.environ["API_KEY"]
API_URL = "https://api.balldontlie.io/v1/players"
firehose = boto3.client("firehose")


def lambda_handler(event, context):
    try:
        # Get yesterday's date
        end_date = datetime.utcnow().date()
        start_date = end_date - timedelta(days=1)

        params = {
            "start_date": start_date.isoformat(),
            "end_date": end_date.isoformat(),
            "per_page": 100,
        }

        headers = {"Authorization": API_KEY}
        response = requests.get(API_URL, params=params, headers=headers)
        response.raise_for_status()
        stats_data = response.json().get("data", [])

        if not stats_data:
            print("No stats data found.")
            return {"statusCode": 204, "body": "No new stats to ingest."}

        for record in stats_data:
            payload = json.dumps(record) + "\n"
            firehose.put_record(
                DeliveryStreamName=FIREHOSE_NAME, Record={"Data": payload}
            )

        print(f"✅ Ingested {len(stats_data)} stat records.")
        return {"statusCode": 200, "body": f"Ingested {len(stats_data)} stat records."}

    except Exception as e:
        print(f"❌ Error: {e}")
        return {"statusCode": 500, "body": str(e)}
