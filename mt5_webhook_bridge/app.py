"""Webhook receiver for TradingView alert_message payloads -> MT5 orders.

Run with:  python app.py          (dev)
           waitress-serve app:app (recommended on Windows for real use)
"""
import hmac
import logging
import logging.handlers

from flask import Flask, jsonify, request

import config
import mt5_bridge

app = Flask(__name__)

handler = logging.handlers.RotatingFileHandler(
    config.LOG_FILE, maxBytes=2_000_000, backupCount=3
)
handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(name)s: %(message)s"))
logging.getLogger().addHandler(handler)
logging.getLogger().addHandler(logging.StreamHandler())
logging.getLogger().setLevel(logging.INFO)
logger = logging.getLogger("webhook_app")

REQUIRED_FIELDS = ("action", "symbol", "strategy")


def _authorized(req) -> bool:
    if not config.WEBHOOK_SECRET:
        # No secret configured means the endpoint is wide open — only
        # acceptable for local DRY_RUN testing, never for a live deployment.
        return config.DRY_RUN
    supplied = req.headers.get("X-Webhook-Secret") or req.args.get("secret") or ""
    return hmac.compare_digest(supplied, config.WEBHOOK_SECRET)


@app.route("/webhook", methods=["POST"])
def webhook():
    if not _authorized(request):
        logger.warning("Rejected webhook: bad/missing secret from %s", request.remote_addr)
        return jsonify({"status": "error", "message": "unauthorized"}), 401

    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        logger.warning("Rejected webhook: body is not JSON object: %r", request.data[:500])
        return jsonify({"status": "error", "message": "expected a JSON object body"}), 400

    missing = [f for f in REQUIRED_FIELDS if not payload.get(f)]
    if missing:
        logger.warning("Rejected webhook: missing fields %s, payload=%s", missing, payload)
        return jsonify({"status": "error", "message": f"missing fields: {missing}"}), 400

    logger.info("Received signal: %s", payload)
    try:
        result = mt5_bridge.handle_signal(payload)
    except Exception as exc:  # noqa: BLE001 — surface every failure to the caller/log
        logger.exception("Failed to handle signal %s", payload)
        return jsonify({"status": "error", "message": str(exc)}), 500

    return jsonify({"status": "ok", "dry_run": config.DRY_RUN, "result": result})


@app.route("/healthz", methods=["GET"])
def healthz():
    return jsonify({"status": "ok", "dry_run": config.DRY_RUN})


if __name__ == "__main__":
    logger.info("Starting webhook bridge on port %s (DRY_RUN=%s)", config.PORT, config.DRY_RUN)
    app.run(host="0.0.0.0", port=config.PORT)
