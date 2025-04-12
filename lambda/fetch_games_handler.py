import json
import os
import boto3
import requests
from datetime import datetime, timedelta

FIREHOSE_NAME = os.environ["FIREHOSE_NAME"]
API_URL = "https://www.balldontlie.io/api/v1/games"
firehose = boto3.client("firehose")

def lambda_handler(event, context):
    try:
        # Get yesterday's date
        end_date = datetime.utcnow().date()
        start_date = end_date - timedelta(days=1)

        params = {
            "start_date": start_date.isoformat(),
            "end_date": end_date.isoformat(),
            "per_page": 100
        }

        response = requests.get(API_URL, params=params)
        response.raise_for_status()
        games_data = response.json().get("data", [])

        if not games_data:
            print("No game data found.")
            return {"statusCode": 204, "body": "No new games to ingest."}

        for record in games_data:
            payload = json.dumps(record) + "\n"
            firehose.put_record(
                DeliveryStreamName=FIREHOSE_NAME,
                Record={"Data": payload}
            )

        print(f"✅ Ingested {len(games_data)} game records.")
        return {"statusCode": 200, "body": f"Ingested {len(games_data)} game records."}

    except Exception as e:
        print(f"❌ Error: {e}")
        return {"statusCode": 500, "body": str(e)}
