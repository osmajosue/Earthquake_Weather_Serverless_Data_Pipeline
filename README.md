# Earthquake & Weather Serverless Data Pipeline (Terraform + AWS + Grafana)

## 📌 Overview
This is a personal project to build a 100% serverless, cloud-native data pipeline on AWS using Terraform. It ingests real-time **Earthquake data from USGS** and enriches it with **Weather data from Open-Meteo**, processes and transforms it using AWS Glue and Apache Iceberg, analyzes it via Athena, and visualizes the results in Grafana.

---

## 📊 Architecture Diagram
(Architecture Diagram coming soon.)

---

## 🧩 Features
- Scheduled ingestion of Earthquake data using AWS Lambda + EventBridge.
- Real-time delivery into S3 via Kinesis Firehose.
- On-demand weather enrichment with Lambda (dynamic archive vs forecast API).
- Storage across Raw, Processed, and Gold (Iceberg) layers in S3.
- PySpark-based transformation and enrichment using AWS Glue.
- Glue Crawler to catalog processed data automatically.
- Glue Workflow to orchestrate ETL, quality checks, and Iceberg writes.
- Iceberg Table (Gold Layer) allowing efficient Athena queries.
- Grafana dashboards to visualize earthquakes, weather conditions, and correlations.
- Entire infrastructure defined and managed with Terraform.

---

## 📈 Example Questions Answered
- Where and when did recent earthquakes occur?
- Which regions experience the highest frequency of earthquakes?
- What were the weather conditions at earthquake locations?
- Does earthquake magnitude correlate with temperature, humidity, or wind?

---

## 🛠 Infrastructure (Provisioned by Terraform)
- **S3 Buckets**: Raw, Processed, Gold Layer, and Scripts.
- **Lambda Functions**: Earthquake Fetcher, Weather Enrichment Fetcher.
- **Kinesis Firehose**: Stream earthquakes into S3.
- **Glue Jobs**:
  - ETL Transformation.
  - Data Quality Check.
  - Write to Iceberg Table.
- **Glue Workflow**: Full orchestration of ETL pipeline.
- **Athena**: Query raw, processed, and Iceberg data layers.
- **Grafana**: Connected to Athena for visualization.
- **Terraform**: Complete cloud infrastructure automation.

---

## 🌍 APIs Used
- [USGS Earthquake API](https://earthquake.usgs.gov/)
- [Open-Meteo API](https://open-meteo.com/)

---

## 🧱 Folder Structure
```bash
earthquake-weather-pipeline/
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── transformation_job.py
│   ├── quality_check.py
│   ├── write_to_gold.py
│   └── *.zip (Lambda deployment packages)
├── lambda/
│   ├── fetch_earthquakes.py
│   └── fetch_weather.py
├── athena/
│   ├── queries.sql
│   └── dashboard_queries.sql
├── grafana/
│   └── dashboard.json
├── README.md
└── .env.example
```

---

## 🚀 Deployment Instructions

### 1. Install Required Tools
Install:
- [Terraform CLI](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) (tested with Terraform 1.5+)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

Configure AWS CLI:
```bash
aws configure
```
Enter:
- AWS Access Key ID
- AWS Secret Access Key
- Default region name (e.g., `us-east-1`)

---

### 2. Clone the Repository
```bash
git clone https://github.com/osmajosue/Earthquake_Weather_Serverless_Data_Pipeline.git
cd earthquake-weather-pipeline
```

---

### 3. Set Up Environment Variables
Copy and edit the `.env` file:
```bash
cp .env.example .env
```
Set the following:
- AWS Region
- Project Prefix (resource naming)
- Bucket Prefix (must be S3-compliant)

---

### 4. Initialize and Apply Terraform
```bash
cd terraform/
terraform init
terraform apply
```
Terraform will provision:
- S3 Buckets
- Lambda Functions
- Kinesis Firehose
- Glue Jobs
- Glue Crawler
- Glue Workflow
- IAM Roles
- Iceberg Layer setup for Athena

---

### 5. Test the Data Pipeline
- Trigger the **Earthquake Fetch Lambda** (manually or wait for scheduled run).
- Trigger the **Weather Fetch Lambda** manually to enrich quake data.
- Trigger the **Glue Workflow** to:
  - Transform the data.
  - Validate (quality check) the data.
  - Append to the Iceberg Gold table.

---

### 6. Connect Grafana to Athena
- Set Athena as a data source in Grafana.
- Configure the correct S3 location for Athena query results.
- Import example queries or build dashboards with Geomap, Scatterplot, and Time Series panels.

---

## 🧠 Important Notes
- This project is intended for **personal learning, experimentation, and portfolio building**.
- It is **not production-ready** without additional hardening, error handling, retries, monitoring, and security enhancements.
- Raw, Processed, and Gold layers are fully separated across S3.
- Iceberg tables allow incremental updates and partition-based querying in Athena.
- Weather enrichment dynamically uses Forecast API for recent quakes and Archive API for older events.
- Grafana dashboards visualize seismic activity correlated with environmental factors.

---

## 🛡️ Security Considerations
- IAM roles and policies are scoped reasonably but are more permissive than production standards (some wildcards are used).
- S3 Buckets are created with `force_destroy = true` for easy cleanup (not recommended for production).
- Athena Workgroup and result configuration should be reviewed for fine-grained control in production environments.
- Secrets or sensitive keys (if any) are managed via Lambda environment variables (no external secrets manager integration).
- No VPC private networking or private endpoints are configured in this project (public service calls only).

---