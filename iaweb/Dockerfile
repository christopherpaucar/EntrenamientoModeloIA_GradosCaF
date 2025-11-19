FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# System deps
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential libpq-dev gcc curl netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# Copy and install requirements
COPY requirements.txt /app/requirements.txt
RUN pip install --upgrade pip
RUN pip install -r /app/requirements.txt

# Copy project
COPY . /app

# Make entrypoint executable
RUN chmod +x /app/entrypoint.sh

ENV DJANGO_SETTINGS_MODULE=iaweb.settings

EXPOSE 8000

ENTRYPOINT ["/app/entrypoint.sh"]
