SELECT
  latitude,
  longitude,
  magnitude,
  quake_time
FROM 
  "eq_weather_pipeline_db"."earthquake_weather_iceberg"
WHERE
  $__timeFilter(quake_time)
  AND latitude IS NOT NULL
  AND longitude IS NOT NULL