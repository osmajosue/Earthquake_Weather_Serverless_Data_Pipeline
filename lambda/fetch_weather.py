import os
import json
import boto3
import requests
from datetime import datetime, timedelta

# Setup clients and environment variables
s3 = boto3.client("s3")
RAW_BUCKET = os.environ["RAW_BUCKET"]
QUAKE_PREFIX = os.environ.get("QUAKE_PREFIX", "raw/earthquakes/")
WEATHER_PREFIX = os.environ.get("WEATHER_PREFIX", "raw/weather_data/")

# Define weather fields you want from Open-Meteo
OPEN_METEO_URL = "https://api.open-meteo.com/v1/forecast"
WEATHER_PARAMS = {"hourly": "temperature_2m,relative_humidity_2m,wind_speed_10m"}


def lambda_handler(event, context):
    try:
        # Define time window (last 24 hours)
        yesterday = (datetime.utcnow() - timedelta(days=1)).strftime("%Y/%m/%d")

        # List all quake files from yesterday
        response = s3.list_objects_v2(
            Bucket=RAW_BUCKET, Prefix=f"{QUAKE_PREFIX}{yesterday}/"
        )
        quake_files = response.get("Contents", [])

        if not quake_files:
            print("No earthquake files found.")
            return {"statusCode": 204, "body": "No quake data to enrich."}

        for quake_file in quake_files:
            quake_obj = s3.get_object(Bucket=RAW_BUCKET, Key=quake_file["Key"])
            lines = quake_obj["Body"].read().decode("utf-8").splitlines()

            for line in lines:
                quake = json.loads(line)
                coords = quake.get("geometry", {}).get("coordinates", [])
                if len(coords) < 2:
                    continue  # skip malformed

                lon, lat = coords[0], coords[1]

                # Build API request
                params = WEATHER_PARAMS.copy()
                params["latitude"] = lat
                params["longitude"] = lon
                weather_response = requests.get(OPEN_METEO_URL, params=params)
                weather_response.raise_for_status()
                weather_data = weather_response.json()

                # Save weather data
                timestamp = datetime.utcnow().strftime("%Y-%m-%dT%H-%M-%S")
                quake_id = quake.get("id", "unknown")
                output_key = f"{WEATHER_PREFIX}{quake_id}_{timestamp}.json"
                s3.put_object(
                    Bucket=RAW_BUCKET, Key=output_key, Body=json.dumps(weather_data)
                )

                print(f"✅ Enriched quake {quake_id} → {output_key}")

        return {
            "statusCode": 200,
            "body": "Weather data fetched for all recent quakes.",
        }

    except Exception as e:
        print(f"❌ Error: {e}")
        return {"statusCode": 500, "body": str(e)}
