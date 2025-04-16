import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql import SparkSession
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.functions import (
    col,
    from_unixtime,
    round as round_col,
    to_date,
    to_timestamp,
)

# Setup Glue context
args = getResolvedOptions(sys.argv, ["JOB_NAME"])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args["JOB_NAME"], args)

# Input paths (adjust if needed)
earthquake_path = "s3://eq-weather-raw-data/earthquakes/"
weather_path = "s3://eq-weather-raw-data/weather_data/"

# Output path
output_path = "s3://eq-weather-processed-data/earthquake_weather/"

# Read Earthquake Data
df_quake = spark.read.option("recursiveFileLookup", "true").json(earthquake_path)

# Clean and transform earthquake data
df_quake = df_quake.filter(
    col("geometry.coordinates").isNotNull() & col("properties.time").isNotNull()
)

# Standarize columns
df_quake = (
    df_quake.withColumn("longitude", round_col(col("geometry.coordinates")[0], 2))
    .withColumn("latitude", round_col(col("geometry.coordinates")[1], 2))
    .withColumn("quake_time", from_unixtime(col("properties.time") / 1000))
    .withColumn("quake_date", to_date(from_unixtime(col("properties.time") / 1000)))
)

df_quake = df_quake.select(
    "id",
    "latitude",
    "longitude",
    "quake_time",
    "quake_date",
    col("properties.mag").alias("magnitude"),
    col("properties.place").alias("location"),
)

# Read Weather Data
df_weather = spark.read.json(weather_path)

df_weather = df_weather.filter(
    col("quake_time").isNotNull()
    & col("latitude").isNotNull()
    & col("longitude").isNotNull()
)

df_weather = (
    df_weather.withColumn("latitude", round_col(col("latitude"), 2))
    .withColumn("longitude", round_col(col("longitude"), 2))
    .withColumn("weather_time", col("quake_time"))
    .withColumn("weather_date", to_date(col("quake_time")))
)

df_weather = df_weather.select(
    "latitude",
    "longitude",
    "weather_time",
    "weather_date",
    "temperature_2m",
    "relative_humidity_2m",
    "wind_speed_10m",
)

df_weather_renamed = df_weather.withColumnRenamed(
    "latitude", "weather_latitude"
).withColumnRenamed("longitude", "weather_longitude")

# Join Earthquake + Weather on lat/lon and date
df_joined = df_quake.join(
    df_weather_renamed,
    (df_quake.latitude == df_weather_renamed.weather_latitude)
    & (df_quake.longitude == df_weather_renamed.weather_longitude)
    & (df_quake.quake_date == df_weather_renamed.weather_date),
    how="inner",
)

# Type cast for better processing
df_joined = (
    df_joined.withColumn("quake_time", to_timestamp(col("quake_time")))
    .withColumn("weather_time", to_timestamp(col("weather_time")))
    .withColumn("temperature_2m", col("temperature_2m").cast("double"))
    .withColumn("relative_humidity_2m", col("relative_humidity_2m").cast("double"))
    .withColumn("wind_speed_10m", col("wind_speed_10m").cast("double"))
)
# Write result to processed bucket in Parquet format, partitioned by date
df_joined.write.mode("overwrite").partitionBy("quake_date").parquet(output_path)

job.commit()
