# Earthquake & Weather Serverless Data Pipeline (Terraform + AWS + Grafana)

## 📌 Overview
A 100% serverless data engineering project built on AWS using Terraform. It ingests real-time **Earthquake data from USGS** and **Weather data from Open-Meteo**, processes and transforms it using AWS Glue, analyzes it via Athena, and visualizes key insights in Grafana.

---

## 📊 Architecture Diagram
![Earthquake + Weather Serverless Architecture] Coming soon

---

## 🧩 Features
- Scheduled ingestion using AWS Lambda + EventBridge
- Real-time delivery via Kinesis Firehose (for earthquake events)
- On-demand Lambda-based enrichment with weather data per location
- Raw and processed data stored in S3
- PySpark-based transformation in AWS Glue
- AWS Glue Data Catalog for structured queries
- Athena SQL for analytical exploration
- Grafana visualization for key environmental metrics

---

## 📈 Questions Answered
1. Where and when did the most recent earthquakes occur?
2. Which regions experience the highest frequency of earthquakes?
3. What are the weather conditions at recent earthquake locations?
4. Is there any relationship between seismic activity and weather patterns?

---

## 🧱 Folder Structure
```bash
earthquake-weather-pipeline/
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── glue_job.py
│   └── *.zip (Lambda packages)
├── lambda/
│   ├── fetch_earthquakes.py
│   └── fetch_weather.py
├── athena/
│   └── queries.sql
├── grafana/
│   └── dashboard.json
├── README.md
└── .env.example
```

---

## 🚀 Deployment Instructions

### 1. Clone the repository
Clone this GitHub repo and navigate to the project directory.

### 2. Set up your environment
Copy `.env.example` to `.env` and configure AWS region and project prefix.

### 3. Deploy Infrastructure
Use Terraform to deploy all components: Lambda, S3, Kinesis, Glue, and Athena.

### 4. Test Earthquake Lambda
Invoke the Lambda manually or wait for the scheduled run to fetch earthquake data.

### 5. Fetch Weather Data
Run the weather Lambda (or script) to enrich quake data with local conditions.

### 6. Transform Data with Glue
Run the Glue job to normalize and join earthquake + weather data.

### 7. Query and Visualize
Use Athena to analyze data and Grafana to visualize insights.

---

## 🧠 Tech Stack
- AWS Lambda, EventBridge, S3, Kinesis Firehose
- AWS Glue (PySpark), Glue Crawlers, Data Catalog
- AWS Athena
- Grafana
- Terraform (IaC)
- Earthquake API (USGS): https://earthquake.usgs.gov/
- Weather API (Open-Meteo): https://open-meteo.com/

---

## 💬 Notes
- Terraform provisions all cloud infrastructure automatically.
- Earthquake data is pulled from the public USGS feed in GeoJSON format.
- Weather enrichment uses latitude and longitude for contextual accuracy.
- Partitioning, deduplication, and schema evolution are supported in Glue.