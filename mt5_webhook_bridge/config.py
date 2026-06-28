"""Configuration loaded from environment variables (see .env.example)."""
import json
import os

from dotenv import load_dotenv

load_dotenv()


def _bool(name, default=False):
    val = os.getenv(name)
    if val is None:
        return default
    return val.strip().lower() in ("1", "true", "yes", "on")


MT5_LOGIN = int(os.getenv("MT5_LOGIN", "0") or 0)
MT5_PASSWORD = os.getenv("MT5_PASSWORD", "")
MT5_SERVER = os.getenv("MT5_SERVER", "")
MT5_TERMINAL_PATH = os.getenv("MT5_TERMINAL_PATH", "") or None

WEBHOOK_SECRET = os.getenv("WEBHOOK_SECRET", "")
PORT = int(os.getenv("PORT", "5000"))

# Safety switch: when true (the default), no real order is sent to MT5 —
# every signal is validated and logged only. Flip to false only after you've
# confirmed the dry-run logs look exactly as you expect.
DRY_RUN = _bool("DRY_RUN", default=True)

# Per-strategy magic numbers so "close" signals only ever touch positions
# this bridge opened, never a position you placed manually in the terminal.
STRATEGY_MAGIC = {
    "ICT-MTF-Confluence": 100001,
    "1H-Retrace-FVG-Retest": 100002,
    "SMC-OB-Liquidity-Sweep": 100003,
    "London-Asian-Breakout": 100004,
}
DEFAULT_MAGIC = int(os.getenv("DEFAULT_MAGIC", "100099"))


def magic_for(strategy_name: str) -> int:
    return STRATEGY_MAGIC.get(strategy_name, DEFAULT_MAGIC)


# Maps the TradingView "symbol" field to whatever your broker actually calls
# that symbol in MT5 (many brokers add a suffix, e.g. EURUSD -> EURUSD.a).
# Set via SYMBOL_MAP as a JSON object string in .env, e.g.:
#   SYMBOL_MAP={"EURUSD": "EURUSD.a", "XAUUSD": "XAUUSD.c"}
_raw_symbol_map = os.getenv("SYMBOL_MAP", "")
try:
    SYMBOL_MAP = json.loads(_raw_symbol_map) if _raw_symbol_map else {}
except json.JSONDecodeError:
    SYMBOL_MAP = {}

# Optional fallback suffix appended to any symbol not found in SYMBOL_MAP,
# tried only if the bare symbol isn't recognized by the broker.
SYMBOL_SUFFIX = os.getenv("SYMBOL_SUFFIX", "")

LOG_FILE = os.getenv("LOG_FILE", "webhook_bridge.log")

# Hard ceiling on lot size the bridge will ever send, regardless of what the
# incoming "qty" field says — a sanity backstop against a bad/garbled payload.
MAX_LOT_SIZE = float(os.getenv("MAX_LOT_SIZE", "10"))

DEVIATION_POINTS = int(os.getenv("DEVIATION_POINTS", "20"))
