FROM python:3.11-slim
ENV PYTHONUNBUFFERED=1
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
RUN useradd --create-home appuser
USER appuser
# Cloud Run injects PORT (default 8080); gunicorn binds to it.
ENV PORT=8080
CMD ["sh", "-c", "exec gunicorn --bind :$PORT --workers 2 main:app"]
