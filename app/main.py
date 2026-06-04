"""A minimal, hardened sample service for the secure Cloud Run deployment.

It exists to be *deployed securely*, not to do much: it returns security
response headers, a health check, and confirms (without ever echoing it) that
the secret injected from Secret Manager is present.
"""
import os

from flask import Flask, jsonify

app = Flask(__name__)


@app.after_request
def security_headers(resp):
    resp.headers["X-Content-Type-Options"] = "nosniff"
    resp.headers["X-Frame-Options"] = "DENY"
    resp.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    resp.headers["Content-Security-Policy"] = "default-src 'none'"
    resp.headers["Referrer-Policy"] = "no-referrer"
    return resp


@app.get("/")
def index():
    return jsonify(service="secure-app", status="running")


@app.get("/health")
def health():
    # Named /health, not /healthz: Google's edge intercepts the literal path
    # /healthz on *.run.app before the request reaches the container.
    return jsonify(status="ok")


@app.get("/secretz")
def secretz():
    # Proves the Secret Manager wiring works without leaking the value.
    return jsonify(jwt_secret_loaded=bool(os.environ.get("JWT_SECRET")))


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
