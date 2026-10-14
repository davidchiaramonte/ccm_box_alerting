# CCM Toolkit Alerting - Decoupled Deployment Guide

This guide provides a comprehensive walkthrough for deploying the **CCM Anomaly Detection & Alerting pipeline** in your private GCP environment.

This repository (`ccm-toolkit-alert`) manages the alerting application, Cloud Run compute engine, Pub/Sub queues, and the alerting BigQuery logic. It is designed as a **decoupled child module** that mounts cleanly on top of the [GCP Cloud Cost Management Toolkit (OSS)](https://github.com/GoogleCloudPlatform/cloud-cost-management-toolkit) core data pipeline.

---

## The Architecture: Decoupled & Modular

To support flexible enterprise deployments and avoid complex state conflicts, the pipeline is split into two independent modules:
1. **[CCM Core Dataform Pipeline (OSS)](https://github.com/GoogleCloudPlatform/cloud-cost-management-toolkit)**: Provisions the BigQuery billing dataset, GCP Dataform repository, and service accounts. (Must be deployed first!)
2. **CCM Anomaly Alerting App (This Repo)**: Provisions the Cloud Run alerting app, Pub/Sub, and Anomaly Detection BigQuery views. It mounts on top of the OSS dataset statically using variables.
