# CCM Toolkit Alerting - Decoupled Deployment Guide

This guide provides a comprehensive walkthrough for deploying the **CCM Anomaly Detection & Alerting pipeline** in your private GCP environment.

This repository (`ccm-toolkit-alert`) manages the alerting application, Cloud Run compute engine, Pub/Sub queues, and the alerting BigQuery logic. It is designed as a **decoupled child module** that mounts cleanly on top of the [GCP Cloud Cost Management Toolkit (OSS)](https://github.com/GoogleCloudPlatform/cloud-cost-management-toolkit) core data pipeline.

---

## The Architecture: Decoupled & Modular

To support flexible enterprise deployments and avoid complex state conflicts, the pipeline is split into two independent modules:
1. **[CCM Core Dataform Pipeline (OSS)](https://github.com/GoogleCloudPlatform/cloud-cost-management-toolkit)**: Provisions the BigQuery billing dataset, GCP Dataform repository, and service accounts. (Must be deployed first!)
2. **CCM Anomaly Alerting App (This Repo)**: Provisions the Cloud Run alerting app, Pub/Sub, and Anomaly Detection BigQuery views. It mounts on top of the OSS dataset statically using variables.

## Gemini Alert Explanations

Each alert email includes a short Gemini-generated explanation and corrective actions.

- `gemini_model_name`: Vertex AI model (default `gemini-3.8-flash`).
- `gemini_thinking_budget` (default `128`): Gemini 3.x "thinking" tokens count against `gemini_max_output_tokens`. Without a cap, thinking can consume nearly the whole budget and cut the explanation off mid-sentence. Use `-1` for dynamic thinking (then raise `gemini_max_output_tokens`).
- `gemini_max_output_tokens` (default `1000`).

### Optional: Recommender-aware alerts

Set `enable_recommendations_in_alerts = true` to add the project's active Google Cloud Recommender recommendations (top 5 by estimated monthly savings, excluding CUD purchases) to the Gemini prompt, so corrective actions can name specific resources and Google's estimated savings.

Prerequisites: the CCM toolkit must run with `enable_recommendations = true` and a Recommender BigQuery export, which creates `vw_active_recommendations` in the billing dataset.

