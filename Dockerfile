# Build the React/Vite frontend, then serve it with the Python Flask backend.
FROM node:20-alpine AS frontend-builder
WORKDIR /build/frontend
COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci
COPY frontend/ ./
RUN npm run build

FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

# The spaCy model is optional; the application should still start if download is unavailable.
RUN python -m spacy download en_core_web_sm || true

COPY backend/ /app/backend/
COPY sample_documents/ /app/sample_documents/
COPY scripts/ /app/scripts/
COPY run.py /app/run.py
COPY --from=frontend-builder /build/frontend/dist /app/frontend/dist

RUN mkdir -p /app/backend/instance /app/backend/uploads /app/backend/exports

# Render supplies PORT dynamically. Gunicorn binds to that port.
CMD ["sh", "-c", "gunicorn --workers 2 --threads 4 --timeout 120 --bind 0.0.0.0:${PORT:-10000} 'backend.app:create_app()'"]
