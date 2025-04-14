import os
import json
import boto3
import requests
from datetime import datetime, timedelta

# Setup clients and environment variables
s3 = boto3.client("s3")
RAW_BUCKET = os.environ["RAW_BUCKET"]
QUAKE_PREFIX = os.environ.get("QUAKE_PREFIX", "earthquakes/")
WEATHER_PREFIX = os.environ.get("WEATHER_PREFIX", "weather_data/")

# Historical weather endpoint
OPEN_METEO_ARCHIVE_URL = "https://archive-api.open-meteo.com/v1/archive"

# Weather fields to enrich with
WEATHER_PARAMS = {"hourly": "temperature_2m,relative_humidity_2m,wind_speed_10m"}


def lambda_handler(event, context):
    try:
        # Try both today and yesterday
        for offset in [0, 1]:
            date_str = (datetime.utcnow() - timedelta(days=offset)).strftime("%Y/%m/%d")
            prefix = f"{QUAKE_PREFIX}{date_str}"
            print(f"🔍 Checking prefix: {prefix}")

            response = s3.list_objects_v2(Bucket=RAW_BUCKET, Prefix=prefix)
            quake_files = response.get("Contents", [])
            if quake_files:
                print(f"✅ Found {len(quake_files)} files under {prefix}")
                break
        else:
            print("❌ No earthquake files found in either today or yesterday.")
            return {"statusCode": 204, "body": "No quake data to enrich."}

        for quake_file in quake_files:
            print(f"📂 Reading file: {quake_file['Key']}")
            quake_obj = s3.get_object(Bucket=RAW_BUCKET, Key=quake_file["Key"])
            lines = quake_obj["Body"].read().decode("utf-8").splitlines()

            if not lines:
                print(f"⚠️ Skipping empty file: {quake_file['Key']}")
                continue

            for line in lines:
                try:
                    quake = json.loads(line)
                    coords = quake.get("geometry", {}).get("coordinates", [])
                    timestamp_ms = quake.get("properties", {}).get("time")

                    if len(coords) < 2 or not timestamp_ms:
                        print("⚠️ Missing coordinates or timestamp.")
                        continue

                    lon, lat = coords[0], coords[1]
                    quake_time = datetime.utcfromtimestamp(timestamp_ms / 1000.0)
                    quake_date = quake_time.strftime("%Y-%m-%d")
                    quake_hour = quake_time.hour

                    # Prepare Open-Meteo historical request
                    params = WEATHER_PARAMS.copy()
                    params["latitude"] = lat
                    params["longitude"] = lon
                    params["start_date"] = quake_date
                    params["end_date"] = quake_date

                    weather_response = requests.get(
                        OPEN_METEO_ARCHIVE_URL, params=params
                    )
                    weather_response.raise_for_status()
                    weather_data = weather_response.json()

                    # Match the weather to the quake hour
                    weather_record = {}
                    hourly_data = weather_data.get("hourly", {})
                    times = hourly_data.get("time", [])

                    if times:
                        for i, t in enumerate(times):
                            record_hour = datetime.strptime(t, "%Y-%m-%dT%H:%M").hour
                            if record_hour == quake_hour:
                                weather_record = {
                                    "quake_time": quake_time.isoformat(),
                                    "latitude": lat,
                                    "longitude": lon,
                                    "temperature_2m": hourly_data.get(
                                        "temperature_2m", []
                                    )[i],
                                    "relative_humidity_2m": hourly_data.get(
                                        "relative_humidity_2m", []
                                    )[i],
                                    "wind_speed_10m": hourly_data.get(
                                        "wind_speed_10m", []
                                    )[i],
                                }
                                break

                    if not weather_record:
                        print(
                            f"⚠️ No matching weather hour found for quake at {quake_time}"
                        )
                        continue

                    quake_id = quake.get("id", "unknown")
                    output_key = f"{WEATHER_PREFIX}{quake_id}_{quake_time.strftime('%Y-%m-%dT%H-%M-%S')}.json"

                    s3.put_object(
                        Bucket=RAW_BUCKET,
                        Key=output_key,
                        Body=json.dumps(weather_record),
                    )

                    print(f"✅ Enriched quake {quake_id} → {output_key}")

                except Exception as e:
                    print(f"⚠️ Failed to process record: {e}")
                    continue

        return {
            "statusCode": 200,
            "body": "Weather data enrichment completed for recent quakes.",
        }

    except Exception as e:
        print(f"❌ Lambda error: {e}")
        return {"statusCode": 500, "body": str(e)}
