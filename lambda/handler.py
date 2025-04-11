import os
import json
import boto3
import requests
from datetime import datetime

s3 = boto3.client("s3")
RAW_BUCKET_NAME = os.getenv("RAW_BUCKET_NAME")


def lambda_handler(event, context):
    try:
        # Fetch games from Balldontlie API (last 1 day)
        today = datetime.utcnow().strftime("%Y-%m-%d")
        url = f"https://www.balldontlie.io/api/v1/games?start_date={today}&end_date={today}&per_page=100"
        response = requests.get(url)
        response.raise_for_status()

        games_data = response.json().get("data", [])
        if not games_data:
            return {"statusCode": 204, "body": json.dumps("No games found for today.")}

        # Save to S3
        file_key = f"raw/games/{today}.json"
        s3.put_object(
            Bucket=RAW_BUCKET_NAME,
            Key=file_key,
            Body=json.dumps(games_data),
            ContentType="application/json",
        )

        return {
            "statusCode": 200,
            "body": f"{len(games_data)} games stored in S3: {file_key}",
        }

    except Exception as e:
        return {"statusCode": 500, "body": json.dumps(str(e))}
