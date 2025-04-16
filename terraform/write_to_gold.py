from pyspark.sql import SparkSession


# Initialize Spark session with Iceberg + Glue Catalog config
spark = (
    SparkSession.builder.appName("WriteToIceberg")
    .config("spark.sql.catalog.spark_catalog", "org.apache.iceberg.spark.SparkCatalog")
    .config(
        "spark.sql.catalog.spark_catalog.warehouse",
        "s3://eq-weather-gold-data/",
    )
    .config(
        "spark.sql.catalog.spark_catalog.catalog-impl",
        "org.apache.iceberg.aws.glue.GlueCatalog",
    )
    .config(
        "spark.sql.catalog.spark_catalog.io-impl", "org.apache.iceberg.aws.s3.S3FileIO"
    )
    .getOrCreate()
)

# Parameters
database = "eq_weather_pipeline_db"
table = "earthquake_weather_iceberg"
catalog = "spark_catalog"
full_table_name = f"{catalog}.{database}.{table}"
s3_path = "s3://eq-weather-processed-data/earthquake_weather/"


# Load processed data from S3 (produced by Glue Job)
df = spark.read.parquet(s3_path)

# Optionally: create Iceberg table if it doesn't exist
spark.sql(
    f"""
CREATE TABLE IF NOT EXISTS {full_table_name} (
    id STRING,
    latitude DOUBLE,
    longitude DOUBLE,
    quake_time TIMESTAMP,
    quake_date DATE,
    magnitude DOUBLE,
    location STRING,
    weather_time TIMESTAMP,
    weather_date DATE,
    temperature_2m DOUBLE,
    relative_humidity_2m DOUBLE,
    wind_speed_10m DOUBLE
)
USING iceberg
PARTITIONED BY (quake_date)
"""
)

df = df.select(
    "id",
    "latitude",
    "longitude",
    "quake_time",
    "quake_date",
    "magnitude",
    "location",
    "weather_time",
    "weather_date",
    "temperature_2m",
    "relative_humidity_2m",
    "wind_speed_10m",
)
# Append to Iceberg table
df.writeTo(full_table_name).append()

print(f"✅ Successfully appended to {full_table_name}")
