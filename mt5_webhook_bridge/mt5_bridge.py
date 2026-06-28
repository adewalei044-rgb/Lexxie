"""Thin wrapper around the MetaTrader5 Python package.

Only importable/runnable on a Windows machine with a MetaTrader 5 terminal
installed and logged in to the target account — the `MetaTrader5` package
talks to that local terminal process, it does not connect to a broker over
the network itself. DRY_RUN mode (config.DRY_RUN) lets you exercise the rest
of this pipeline (webhook parsing, validation, logging) without that
terminal present, but DRY_RUN never sends a real order.
"""
import logging

import config

logger = logging.getLogger("mt5_bridge")

_mt5 = None
_initialized = False


def _lazy_import_mt5():
    global _mt5
    if _mt5 is None:
        import MetaTrader5 as mt5  # noqa: N813 — package's own casing
        _mt5 = mt5
    return _mt5


def ensure_connected():
    """Initializes the terminal connection once per process. No-op in DRY_RUN."""
    global _initialized
    if config.DRY_RUN:
        return True
    if _initialized:
        return True

    mt5 = _lazy_import_mt5()
    kwargs = {}
    if config.MT5_TERMINAL_PATH:
        kwargs["path"] = config.MT5_TERMINAL_PATH
    if config.MT5_LOGIN:
        kwargs.update(
            login=config.MT5_LOGIN,
            password=config.MT5_PASSWORD,
            server=config.MT5_SERVER,
        )

    if not mt5.initialize(**kwargs):
        code, desc = mt5.last_error()
        raise RuntimeError(f"MT5 initialize() failed: [{code}] {desc}")

    _initialized = True
    logger.info("Connected to MT5 terminal (account=%s server=%s)",
                config.MT5_LOGIN, config.MT5_SERVER)
    return True


def resolve_symbol(tv_symbol: str) -> str:
    """Maps a TradingView symbol to the broker's MT5 symbol name."""
    mapped = config.SYMBOL_MAP.get(tv_symbol, tv_symbol)

    if config.DRY_RUN:
        return mapped

    mt5 = _lazy_import_mt5()
    info = mt5.symbol_info(mapped)
    if info is None and config.SYMBOL_SUFFIX:
        candidate = mapped + config.SYMBOL_SUFFIX
        if mt5.symbol_info(candidate) is not None:
            mapped = candidate
            info = mt5.symbol_info(mapped)

    if info is None:
        raise ValueError(f"Symbol '{mapped}' not found/visible in MT5 Market Watch")
    if not info.visible:
        mt5.symbol_select(mapped, True)
    return mapped


def _pick_filling_mode(mt5, symbol_info):
    for mode in (mt5.ORDER_FILLING_FOK, mt5.ORDER_FILLING_IOC, mt5.ORDER_FILLING_RETURN):
        if symbol_info.filling_mode & (1 << mode):
            return mode
    return mt5.ORDER_FILLING_FOK


def open_position(symbol: str, side: str, lots: float, sl: float, tp: float,
                   strategy: str, comment: str = ""):
    """side: 'long' or 'short'. Returns a result dict; raises on hard failure."""
    lots = min(abs(lots), config.MAX_LOT_SIZE)
    magic = config.magic_for(strategy)

    if config.DRY_RUN:
        logger.info("[DRY_RUN] would open %s %s lots=%s sl=%s tp=%s magic=%s",
                    side, symbol, lots, sl, tp, magic)
        return {"dry_run": True, "action": "open", "symbol": symbol, "side": side,
                "lots": lots, "sl": sl, "tp": tp, "magic": magic}

    mt5 = _lazy_import_mt5()
    ensure_connected()
    symbol = resolve_symbol(symbol)
    info = mt5.symbol_info(symbol)
    tick = mt5.symbol_info_tick(symbol)
    if info is None or tick is None:
        raise ValueError(f"Could not read symbol/tick info for '{symbol}'")

    order_type = mt5.ORDER_TYPE_BUY if side == "long" else mt5.ORDER_TYPE_SELL
    price = tick.ask if side == "long" else tick.bid

    request = {
        "action": mt5.TRADE_ACTION_DEAL,
        "symbol": symbol,
        "volume": lots,
        "type": order_type,
        "price": price,
        "sl": sl or 0.0,
        "tp": tp or 0.0,
        "deviation": config.DEVIATION_POINTS,
        "magic": magic,
        "comment": (comment or strategy)[:31],
        "type_time": mt5.ORDER_TIME_GTC,
        "type_filling": _pick_filling_mode(mt5, info),
    }
    result = mt5.order_send(request)
    if result is None or result.retcode != mt5.TRADE_RETCODE_DONE:
        code, desc = mt5.last_error()
        raise RuntimeError(
            f"order_send failed: retcode={getattr(result, 'retcode', None)} "
            f"comment={getattr(result, 'comment', None)} last_error=[{code}] {desc}"
        )
    logger.info("Opened %s %s lots=%s ticket=%s", side, symbol, lots, result.order)
    return {"dry_run": False, "ticket": result.order, "retcode": result.retcode}


def close_positions(symbol: str, strategy: str):
    """Closes every open position for this symbol opened by this bridge
    (matched by magic number), regardless of which side it's on."""
    magic = config.magic_for(strategy)

    if config.DRY_RUN:
        logger.info("[DRY_RUN] would close all positions symbol=%s magic=%s", symbol, magic)
        return {"dry_run": True, "action": "close", "symbol": symbol, "magic": magic}

    mt5 = _lazy_import_mt5()
    ensure_connected()
    symbol = resolve_symbol(symbol)
    positions = mt5.positions_get(symbol=symbol)
    if not positions:
        return {"dry_run": False, "closed": 0, "reason": "no matching open positions"}

    closed = []
    for pos in positions:
        if pos.magic != magic:
            continue
        tick = mt5.symbol_info_tick(symbol)
        is_buy = pos.type == mt5.ORDER_TYPE_BUY
        close_type = mt5.ORDER_TYPE_SELL if is_buy else mt5.ORDER_TYPE_BUY
        price = tick.bid if is_buy else tick.ask
        info = mt5.symbol_info(symbol)
        request = {
            "action": mt5.TRADE_ACTION_DEAL,
            "symbol": symbol,
            "volume": pos.volume,
            "type": close_type,
            "position": pos.ticket,
            "price": price,
            "deviation": config.DEVIATION_POINTS,
            "magic": magic,
            "comment": f"close:{strategy}"[:31],
            "type_time": mt5.ORDER_TIME_GTC,
            "type_filling": _pick_filling_mode(mt5, info),
        }
        result = mt5.order_send(request)
        if result is None or result.retcode != mt5.TRADE_RETCODE_DONE:
            code, desc = mt5.last_error()
            logger.error("Failed to close ticket=%s: retcode=%s last_error=[%s] %s",
                         pos.ticket, getattr(result, "retcode", None), code, desc)
            continue
        closed.append(pos.ticket)

    return {"dry_run": False, "closed": len(closed), "tickets": closed}


def handle_signal(payload: dict) -> dict:
    """Routes a parsed TradingView alert payload to the right MT5 action."""
    action = payload.get("action")
    symbol = payload.get("symbol")
    side = payload.get("side")
    strategy = payload.get("strategy", "unknown")

    if not symbol:
        raise ValueError("payload missing 'symbol'")

    if action == "buy":
        return open_position(symbol, "long", payload.get("qty", 1.0),
                              payload.get("sl"), payload.get("tp"), strategy)
    if action == "sell":
        return open_position(symbol, "short", payload.get("qty", 1.0),
                              payload.get("sl"), payload.get("tp"), strategy)
    if action == "close":
        return close_positions(symbol, strategy)

    raise ValueError(f"Unrecognized action '{action}' (expected buy/sell/close)")
