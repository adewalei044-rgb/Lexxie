"""
Lexxie MT5 relay - receives the same webhook JSON as the crypto relay and
places the matching order through a locally-running MetaTrader 5 terminal.

This MUST run on the same Windows machine as the MT5 terminal - the official
MetaTrader5 Python package talks to the terminal over local IPC, it does not
call a remote API. That's why this is a separate project from webhook-relay/
(which runs fine headless on a Linux VPS for Bybit/Bitget).
"""
import os
import math
import logging
from datetime import datetime

import MetaTrader5 as mt5
from flask import Flask, request, jsonify
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")
log = logging.getLogger("lexxie-mt5-relay")

WEBHOOK_SECRET = os.getenv("WEBHOOK_SECRET", "")
SYMBOL_SUFFIX = os.getenv("SYMBOL_SUFFIX", "")
RISK_MONEY = float(os.getenv("RISK_MONEY", "0"))
FIXED_LOT = float(os.getenv("FIXED_LOT", "0.01"))
DEVIATION = int(os.getenv("DEVIATION_POINTS", "20"))
MAGIC = int(os.getenv("MAGIC_NUMBER", "20260703"))

MT5_LOGIN = os.getenv("MT5_LOGIN")
MT5_PASSWORD = os.getenv("MT5_PASSWORD")
MT5_SERVER = os.getenv("MT5_SERVER")
MT5_PATH = os.getenv("MT5_TERMINAL_PATH")  # optional, e.g. C:\...\terminal64.exe

app = Flask(__name__)


def init_mt5():
    kwargs = {}
    if MT5_PATH:
        kwargs["path"] = MT5_PATH
    if not mt5.initialize(**kwargs):
        raise RuntimeError(f"mt5.initialize() failed: {mt5.last_error()}")
    if MT5_LOGIN and MT5_PASSWORD and MT5_SERVER:
        if not mt5.login(int(MT5_LOGIN), password=MT5_PASSWORD, server=MT5_SERVER):
            raise RuntimeError(f"mt5.login() failed: {mt5.last_error()}")
    info = mt5.account_info()
    log.info("Connected to MT5 account #%s on %s", info.login if info else "?", MT5_SERVER or "(already logged in)")


def map_symbol(tv_symbol: str) -> str:
    return tv_symbol + SYMBOL_SUFFIX


def round_to_step(volume: float, step: float, vol_min: float, vol_max: float) -> float:
    stepped = math.floor(volume / step) * step
    stepped = max(vol_min, min(vol_max, stepped))
    decimals = len(str(step).split(".")[-1]) if "." in str(step) else 0
    return round(stepped, decimals)


def compute_lot(symbol_info, price, stop) -> float:
    if RISK_MONEY > 0 and price is not None and stop is not None:
        tick_size = symbol_info.trade_tick_size or symbol_info.point
        tick_value = symbol_info.trade_tick_value
        price_diff = abs(price - stop)
        if tick_size > 0 and price_diff > 0:
            ticks = price_diff / tick_size
            risk_per_lot = ticks * tick_value
            if risk_per_lot > 0:
                lot = RISK_MONEY / risk_per_lot
                return round_to_step(lot, symbol_info.volume_step, symbol_info.volume_min, symbol_info.volume_max)
    return round_to_step(FIXED_LOT, symbol_info.volume_step, symbol_info.volume_min, symbol_info.volume_max)


def send_market_order(symbol, order_type, volume, sl=None, tp=None, position_ticket=None, comment="Lexxie"):
    tick = mt5.symbol_info_tick(symbol)
    if tick is None:
        raise RuntimeError(f"No tick data for {symbol} - is it in Market Watch?")
    price = tick.ask if order_type == mt5.ORDER_TYPE_BUY else tick.bid

    req = {
        "action": mt5.TRADE_ACTION_DEAL,
        "symbol": symbol,
        "volume": volume,
        "type": order_type,
        "price": price,
        "deviation": DEVIATION,
        "magic": MAGIC,
        "comment": comment,
        "type_time": mt5.ORDER_TIME_GTC,
        "type_filling": mt5.ORDER_FILLING_IOC,
    }
    if sl:
        req["sl"] = sl
    if tp:
        req["tp"] = tp
    if position_ticket is not None:
        req["position"] = position_ticket

    result = mt5.order_send(req)
    if result is None or result.retcode != mt5.TRADE_RETCODE_DONE:
        raise RuntimeError(f"order_send failed: retcode={result.retcode if result else None} comment={result.comment if result else mt5.last_error()}")
    return result


def close_position(symbol):
    positions = mt5.positions_get(symbol=symbol)
    if not positions:
        log.info("No open position on %s to close", symbol)
        return None
    pos = positions[0]
    opposite = mt5.ORDER_TYPE_SELL if pos.type == mt5.ORDER_TYPE_BUY else mt5.ORDER_TYPE_BUY
    return send_market_order(symbol, opposite, pos.volume, position_ticket=pos.ticket, comment="Lexxie close")


@app.route("/health")
def health():
    return jsonify({"ok": True, "time": datetime.utcnow().isoformat()})


@app.route("/hook/<secret>", methods=["POST"])
def hook(secret):
    if not WEBHOOK_SECRET or secret != WEBHOOK_SECRET:
        log.warning("Rejected webhook: bad secret")
        return jsonify({"error": "forbidden"}), 403

    payload = request.get_json(silent=True, force=True)
    if not payload:
        return jsonify({"error": "invalid JSON"}), 400

    log.info("Received: %s", payload)

    tv_symbol = payload.get("symbol")
    action = payload.get("action")
    if not tv_symbol or not action:
        return jsonify({"error": "symbol and action are required"}), 400

    symbol = map_symbol(tv_symbol)
    if not mt5.symbol_select(symbol, True):
        return jsonify({"error": f"symbol {symbol} not found/selectable in MT5"}), 400

    try:
        result = None
        if action in ("buy", "sell"):
            info = mt5.symbol_info(symbol)
            if info is None:
                raise RuntimeError(f"No symbol_info for {symbol}")
            price = payload.get("price")
            stop = payload.get("stop")
            target = payload.get("target")
            lot = compute_lot(info, float(price) if price is not None else None,
                               float(stop) if stop is not None else None)
            if lot <= 0:
                raise RuntimeError("Computed lot <= 0, check RISK_MONEY/FIXED_LOT/volume_step")
            order_type = mt5.ORDER_TYPE_BUY if action == "buy" else mt5.ORDER_TYPE_SELL
            result = send_market_order(
                symbol, order_type, lot,
                sl=float(stop) if stop is not None else None,
                tp=float(target) if target is not None else None,
            )
        elif action in ("close_long", "close_short"):
            result = close_position(symbol)
        else:
            return jsonify({"error": f"unknown action: {action}"}), 400

        log.info("Order result: %s", result)
        return jsonify({"ok": True, "result": str(result)})
    except Exception as exc:
        log.exception("Order error")
        return jsonify({"error": str(exc)}), 500


if __name__ == "__main__":
    init_mt5()
    port = int(os.getenv("PORT", "3001"))
    app.run(host="127.0.0.1", port=port)
