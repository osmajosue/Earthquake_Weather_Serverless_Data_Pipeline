SELECT
  CAST(magnitude AS DECIMAL(3,1)),
  COUNT(*) AS quake_count
FROM 
  "eq_weather_pipeline_db"."earthquake_weather_iceberg"
WHERE
  $__timeFilter(quake_time)
GROUP BY
  magnitude
ORDER BY
  magnitude