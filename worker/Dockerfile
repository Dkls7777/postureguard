# syntax=docker/dockerfile:1

FROM python:3.14-slim

WORKDIR /app

# Unbuffered output so logs reach the container runtime immediately —
# the same trap that hid the worker's logs under systemd in Phase 0.
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY worker.py scoring.py ./

RUN useradd --system --create-home --uid 1001 worker
USER worker

CMD ["python", "-u", "worker.py"]
