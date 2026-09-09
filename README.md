# End-to-End-SQL-Analysis-of-UCI-Online-Retail-II
A complete data analytics case study covering data quality, cleaning, sales performance, customer behavior, retention, RFM, CLV, product demand, market basket analysis, and cancellation risk.
1. Introduction
E-commerce datasets often look deceptively simple. A transaction table containing an invoice number, product, quantity, price, customer, date, and country seems sufficient to answer basic questions such as What sold the most? or Which country generated the most revenue? 
But the process of turning this information into a reliable analysis for a presentation or report starts well before any graphs or key performance indicators.
It is crucial to assess the data's reliability and, in some cases, question the transactions' validity.
This project works with the UCI Online Retail II database to practice an end-to-end SQL analytics pipeline. It starts with a basic transaction table and goes through several stages of preparation: auditing the data, creating a cleaned version of the table, and validating the changes. The analysis then proceeds to focus on sales, customers, retention, RFM/CLV, product demand, market baskets, and cancellation rates.
Ultimately, the purpose of this project is to show how the raw information can be turned into a valuable asset for a company, which can be achieved by following a specific analytical pipeline.
Project objectives
The project will focus on five questions:
Can the data be trusted?
 How and why should it be cleaned and validated?
What happened with sales, products, customers, and markets?
What customers and products drive the most value or costs?
What can a company do with this information?

2. Project Overview
Business Context
The dataset represents transactional activity from an online retail business. Each record corresponds to a transaction line associated with an invoice, product, quantity, unit price, customer, date, and country.
This structure makes the dataset suitable for analyzing:
Revenue performance
Order and basket behavior
Product performance
Customer purchasing behavior
Customer retention and churn risk
RFM segmentation
Customer lifetime value
Demand patterns
Product lifecycle
Market basket relationships
Cancellation behavior
Geographic performance

Analytical Workflow
Raw CSV
   ↓
Data Loading
   ↓
Data Understanding
   ↓
Data Quality Audit
   ↓
Data Cleaning
   ↓
Post-Cleaning Validation
   ↓
Business Metrics
   ↓
Sales & Revenue Analysis
   ↓
Product Analysis
   ↓
Geographic Analysis
   ↓
Customer Analytics
   ↓
RFM & CLV
   ↓
Retention & Churn
   ↓
Revenue Intelligence
   ↓
Demand & Product Lifecycle
   ↓
Market Basket Analysis
   ↓
Cancellation Analytics
