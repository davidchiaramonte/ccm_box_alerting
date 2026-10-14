# Copyright 2026 Google LLC
# Transactional FastAPI app container for cost anomaly alerts

FROM python:3.11-slim

# Allow statements and log messages to immediately appear in the server logs
ENV PYTHONUNBUFFERED True

# Establish application directory context inside container
ENV APP_HOME /app
WORKDIR $APP_HOME

# Copy local python application codebase files from app/ folder to container root workdir
COPY app/ ./

# Install application runtime dependencies listed in requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Expose standard Cloud Run port 8080
EXPOSE 8080

# Execute FastAPI service via Uvicorn high-performance server on startup
# Binds to all interfaces on port 8080 as required by Cloud Run lifecycle
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
