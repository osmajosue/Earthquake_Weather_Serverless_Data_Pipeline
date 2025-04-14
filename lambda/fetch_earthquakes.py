import json
import os
import boto3
import requests
from datetime import datetime, timedelta

FIREHOSE_NAME = os.environ["FIREHOSE_NAME"]
USGS_API_URL = "https://earthquake.usgs.gov/fdsnws/event/1/query"
firehose = boto3.client("firehose")


def lambda_handler(event, context):
    try:
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(days=1)

        params = {
            "format": "geojson",
            "starttime": start_time.strftime("%Y-%m-%dT%H:%M:%S"),
            "endtime": end_time.strftime("%Y-%m-%dT%H:%M:%S"),
        }

        response = requests.get(USGS_API_URL, params=params)
        response.raise_for_status()
        data = response.json()
        features = data.get("features", [])

        if not features:
            print("No earthquake data found.")
            return {"statusCode": 204, "body": "No earthquake data to ingest."}

        for quake in features:
            record = json.dumps(quake) + "\n"
            firehose.put_record(
                DeliveryStreamName=FIREHOSE_NAME, Record={"Data": record}
            )

        print(f"✅ Ingested {len(features)} earthquake records.")
        return {
            "statusCode": 200,
            "body": f"Ingested {len(features)} earthquake records.",
        }

    except Exception as e:
        print(f"❌ Error: {e}")
        return {"statusCode": 500, "body": str(e)}
