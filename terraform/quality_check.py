from pyspark.sql import SparkSession
from pyspark.sql.functions import col, count, isnan, when

# Initialize Spark session
spark = SparkSession.builder.appName("QualityCheck").getOrCreate()

# Path to the processed dataset
input_path = "s3://eq-weather-processed-data/earthquake_weather/"

# Load the data
df = spark.read.parquet(input_path)

print("🔍 Starting quality checks on processed data...")

# Check for nulls in key columns
key_columns = ["id", "quake_time", "latitude", "longitude"]

for col_name in key_columns:
    null_count = df.filter(col(col_name).isNull())
    print(f"🧪 Null check → {col_name}: {null_count} nulls")

# Check for uniqueness of primary key (id + quake_time)
dupe_count = df.groupBy("id", "quake_time").count().filter("count > 1").count()
print(f"🧪 Duplicate check → (id, quake_time) duplicates: {dupe_count}")

# Data type checks: Ensure certain fields are of expected type
expected_types = {
    "latitude": "DoubleType",
    "longitude": "DoubleType",
    "temperature_2m": "DoubleType",
    "magnitude": "DoubleType",
}

for col_name, expected_type in expected_types.items():
    actual_type = str(df.schema[col_name].dataType)
    print(f"🧪 Type check → {col_name}: {actual_type} (expected: {expected_type})")
    if expected_type not in actual_type:
        print(f"⚠️ Mismatch found in {col_name}!")

# Print summary
row_count = df.count()
print(f"✅ Total rows in processed data: {row_count}")
print("✅ Quality check complete.")
