import json
import os
import boto3
import requests
from datetime import datetime, timedelta

FIREHOSE_NAME = os.environ["FIREHOSE_NAME"]
API_URL = "https://www.balldontlie.io/api/v1/games"
firehose = boto3.client("firehose")


def lambda_handler(event, context):
    # Get date range for last 24 hours
    end_date = datetime.utcnow().date()
    start_date = end_date - timedelta(days=1)

    params = {
        "start_date": start_date.isoformat(),
        "end_date": end_date.isoformat(),
        "per_page": 100,
    }

    try:
        response = requests.get(API_URL, params=params)
        response.raise_for_status()
        data = response.json()["data"]

        if not data:
            print("No games found in the last 24 hours.")
            return {"statusCode": 204, "body": "No games to ingest."}

        for game in data:
            record = json.dumps(game) + "\n"
            firehose.put_record(
                DeliveryStreamName=FIREHOSE_NAME, Record={"Data": record}
            )

        print(f"Successfully ingested {len(data)} records.")
        return {"statusCode": 200, "body": f"Successfully ingested {len(data)} games."}

    except Exception as e:
        print(f"Error fetching or sending data: {e}")
        return {"statusCode": 500, "body": str(e)}
