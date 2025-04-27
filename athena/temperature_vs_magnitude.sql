SELECT
  temperature_2m,
  magnitude
FROM 
  "eq_weather_pipeline_db"."earthquake_weather_iceberg"
WHERE
  $__timeFilter(quake_time)
  AND temperature_2m IS NOT NULL
  AND magnitude IS NOT NULL
ORDER BY
  temperature_2m DESC