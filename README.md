# NBA Serverless Data Pipeline (Terraform + AWS + Grafana)

## 📌 Overview
A 100% serverless data engineering project built on AWS using Terraform. It ingests data from the **Balldontlie NBA API**, processes and transforms it using AWS Glue, analyzes it via Athena, and visualizes key insights in Grafana.

---

## 📊 Architecture Diagram
![NBA Serverless Architecture] Coming soon

---

## 🧩 Features
- Scheduled ingestion using AWS Lambda + EventBridge
- Real-time delivery via Kinesis Firehose
- Raw and processed data stored in S3
- PySpark-based transformation in AWS Glue
- AWS Glue Data Catalog for structured queries
- Athena SQL for dashboard queries
- Grafana visualization of key performance indicators

---

## 📈 Business Questions Answered
1. Which teams have the highest win percentage this season?
2. Which players have the highest average points per game in the last 10 games?
3. Which games had the closest score margins (nail-biters)?
4. What is the scoring trend over time per team?

---

## 🧱 Folder Structure
```bash
nba-pipeline/
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── lambda.zip
│   └── glue_job.py
├── lambda/
│   └── handler.py
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
Clone this GitHub repo and navigate to the directory.

### 2. Set up your environment
Copy the `.env.example` to `.env` and configure variables such as AWS region, bucket name, etc.

### 3. Deploy Infrastructure
Deploy all infrastructure components, including Lambda, Kinesis, S3, Glue, and Athena, using Terraform.

### 4. Test the Lambda
Invoke the Lambda function manually or wait for the scheduled run to ingest NBA game data.

### 5. Process Data with Glue
Run the Glue job to transform and normalize the raw NBA data and store it in the processed S3 path.

### 6. Query with Athena
Use Athena queries to explore the transformed data and prepare inputs for dashboards.

### 7. Visualize in Grafana
Connect Grafana to Athena and import the provided dashboard template to display insights.

---

## 🧠 Tech Stack
- AWS Lambda, EventBridge, S3, Kinesis Firehose
- AWS Glue (PySpark), Glue Crawlers, Glue Data Catalog
- AWS Athena
- Grafana
- Terraform (IaC)
- Balldontlie NBA API (https://www.balldontlie.io/)

---

## 💬 Notes
- Terraform automates provisioning of all necessary AWS resources.
- Balldontlie API is used for free, public access to NBA stats and player data.
- Glue jobs can be enhanced for partitioning and incremental loads.
- Retry logic should be implemented in Lambda to handle API rate limits gracefully.

