SELECT
  $__timeGroup(quake_time, '1d') AS quake_day,
  AVG(magnitude) AS avg_magnitude
FROM 
  "eq_weather_pipeline_db"."earthquake_weather_iceberg"
WHERE
  $__timeFilter(quake_time)
GROUP BY
  quake_day
ORDER BY
  quake_day