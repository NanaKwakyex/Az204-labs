"""
Lab 01 — App Service sample application
AZ-204: Azure Developer Associate

Demonstrates:
  - Reading app settings (environment variables) injected by App Service
  - Key Vault reference resolution — MY_SECRET is resolved by the platform,
    not by the app; by the time os.getenv runs, it is already plaintext
  - A /health endpoint suitable for App Service health checks
  - A /env endpoint (disabled in production) for inspecting settings
"""

import os
from flask import Flask, jsonify

app = Flask(__name__)

ENVIRONMENT = os.getenv("ENVIRONMENT", "unknown")
MY_SECRET   = os.getenv("MY_SECRET", "not-set")   # resolved from Key Vault by App Service


@app.route("/")
def index():
    return jsonify({
        "lab":         "01 — App Service",
        "environment": ENVIRONMENT,
        "message":     "Deployed via GitHub Actions + Bicep",
    })


@app.route("/health")
def health():
    """
    App Service health check endpoint.
    Configure under Configuration > General Settings > Health check path = /health
    Returns 200 so the platform considers the instance healthy.
    """
    return jsonify({"status": "healthy"}), 200


@app.route("/secret-peek")
def secret_peek():
    """
    Shows the FIRST 4 characters of the resolved Key Vault secret.
    Proves the managed-identity Key Vault reference works without
    ever storing a credential in code or app settings.
    """
    preview = MY_SECRET[:4] + "****" if len(MY_SECRET) > 4 else "****"
    return jsonify({
        "secret_preview": preview,
        "note": "Full value intentionally masked",
    })


@app.route("/env")
def env():
    """Debug endpoint — only available outside production."""
    if ENVIRONMENT == "prod":
        return jsonify({"error": "Not available in production"}), 403

    safe_vars = {
        k: v for k, v in os.environ.items()
        # never leak secrets — only surface non-sensitive settings
        if not any(word in k.upper() for word in ["SECRET", "KEY", "PASSWORD", "TOKEN", "CREDENTIAL"])
    }
    return jsonify(safe_vars)


if __name__ == "__main__":
    # App Service sets PORT via the WEBSITES_PORT / PORT env var.
    port = int(os.getenv("PORT", 8000))
    app.run(host="0.0.0.0", port=port)
