import os
import json
import boto3
import requests
from datetime import datetime, timedelta
from dateutil import parser

# Setup clients and environment variables
s3 = boto3.client("s3")
RAW_BUCKET = os.environ["RAW_BUCKET"]
QUAKE_PREFIX = os.environ.get("QUAKE_PREFIX", "earthquakes/")
WEATHER_PREFIX = os.environ.get("WEATHER_PREFIX", "raw/weather_data/")

# Open-Meteo Endpoints
FORECAST_URL = "https://api.open-meteo.com/v1/forecast"
ARCHIVE_URL = "https://archive-api.open-meteo.com/v1/archive"
WEATHER_PARAMS = {"hourly": "temperature_2m,relative_humidity_2m,wind_speed_10m"}


def lambda_handler(event, context):
    try:
        existing_keys = set()
        paginator = s3.get_paginator("list_objects_v2")
        for page in paginator.paginate(Bucket=RAW_BUCKET, Prefix=WEATHER_PREFIX):
            for obj in page.get("Contents", []):
                existing_keys.add(obj["Key"])
        print(f"📦 Found {len(existing_keys)} existing weather files")

        for offset in [0, 1]:
            date_str = (datetime.utcnow() - timedelta(days=offset)).strftime("%Y/%m/%d")
            prefix = f"{QUAKE_PREFIX}{date_str}"
            print(f"🔍 Checking prefix: {prefix}")
            response = s3.list_objects_v2(Bucket=RAW_BUCKET, Prefix=prefix)
            quake_files = response.get("Contents", [])
            if quake_files:
                print(f"✅ Found {len(quake_files)} quake files under {prefix}")
                break
        else:
            print("❌ No earthquake files found.")
            return {"statusCode": 204, "body": "No quake data to enrich."}

        enriched_count = 0
        skipped_count = 0

        for quake_file in quake_files:
            print(f"📂 Reading file: {quake_file['Key']}")
            quake_obj = s3.get_object(Bucket=RAW_BUCKET, Key=quake_file["Key"])
            lines = quake_obj["Body"].read().decode("utf-8").splitlines()

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
                    quake_id = quake.get("id", "unknown")
                    output_key = f"{WEATHER_PREFIX}{quake_id}_{quake_time.strftime('%Y-%m-%dT%H-%M-%S')}.json"

                    if output_key in existing_keys:
                        print(f"⏭️ Skipping quake {quake_id}, already enriched.")
                        skipped_count += 1
                        continue

                    # 🌦️ Choose forecast or archive API
                    if quake_time.date() >= (
                        datetime.utcnow().date() - timedelta(days=1)
                    ):
                        print(f"📡 Using FORECAST API for {quake_id}")
                        weather_url = FORECAST_URL
                        params = WEATHER_PARAMS.copy()
                        params.update(
                            {"latitude": lat, "longitude": lon, "past_days": 1}
                        )
                    else:
                        print(f"📡 Using ARCHIVE API for {quake_id}")
                        weather_url = ARCHIVE_URL
                        params = WEATHER_PARAMS.copy()
                        params.update(
                            {
                                "latitude": lat,
                                "longitude": lon,
                                "start_date": quake_date,
                                "end_date": quake_date,
                            }
                        )

                    # 🔗 Fetch weather data
                    weather_response = requests.get(weather_url, params=params)
                    weather_response.raise_for_status()
                    weather_data = weather_response.json()

                    hourly = weather_data.get("hourly", {})
                    times = hourly.get("time", [])
                    temps = hourly.get("temperature_2m", [])
                    humidities = hourly.get("relative_humidity_2m", [])
                    winds = hourly.get("wind_speed_10m", [])

                    # 🕒 Match closest hour
                    quake_hour = quake_time.replace(minute=0, second=0, microsecond=0)
                    closest_diff = timedelta(hours=999)
                    matched_index = -1

                    for i, t in enumerate(times):
                        try:
                            record_time = parser.parse(t)
                            diff = abs(record_time - quake_hour)
                            if diff < closest_diff:
                                closest_diff = diff
                                matched_index = i
                        except Exception as parse_err:
                            print(f"⚠️ Time parse error: {parse_err}")
                            continue

                    if matched_index == -1 or matched_index >= min(
                        len(temps), len(humidities), len(winds)
                    ):
                        print(f"⚠️ No valid weather match for quake {quake_id}")
                        continue

                    weather_record = {
                        "quake_time": quake_time.isoformat(),
                        "latitude": lat,
                        "longitude": lon,
                        "temperature_2m": temps[matched_index],
                        "relative_humidity_2m": humidities[matched_index],
                        "wind_speed_10m": winds[matched_index],
                    }

                    print(
                        f"💡 Data for quake {quake_id}: "
                        f"temp={temps[matched_index]}, "
                        f"humidity={humidities[matched_index]}, "
                        f"wind={winds[matched_index]}"
                    )

                    if any(v is None for v in weather_record.values()):
                        print(f"⚠️ Incomplete data for {quake_id}, skipping.")
                        continue

                    s3.put_object(
                        Bucket=RAW_BUCKET,
                        Key=output_key,
                        Body=json.dumps(weather_record),
                    )

                    enriched_count += 1
                    print(f"✅ Enriched quake {quake_id} → {output_key}")

                except Exception as e:
                    print(f"⚠️ Failed to process record: {e}")
                    continue

        print(f"🏁 Done! Enriched: {enriched_count}, Skipped: {skipped_count}")
        return {
            "statusCode": 200,
            "body": f"Enriched: {enriched_count}, Skipped: {skipped_count}",
        }

    except Exception as e:
        print(f"❌ Lambda error: {e}")
        return {"statusCode": 500, "body": str(e)}
