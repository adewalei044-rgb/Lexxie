#!/usr/bin/env python3
"""Fetch technical analysis data from TradingView for a given symbol."""

import argparse
import json
import sys

from tradingview_ta import TA_Handler
from tradingview_ta import get_multiple_analysis as _get_multiple_analysis


def _format_analysis(analysis):
    indicators = analysis.indicators
    return {
        "symbol": analysis.symbol,
        "exchange": analysis.exchange,
        "screener": analysis.screener,
        "interval": analysis.interval,
        "time": str(analysis.time),
        "summary": analysis.summary,
        "oscillators": analysis.oscillators,
        "moving_averages": analysis.moving_averages,
        "price": {
            "close": indicators.get("close"),
            "open": indicators.get("open"),
            "high": indicators.get("high"),
            "low": indicators.get("low"),
            "volume": indicators.get("volume"),
            "change_percent": indicators.get("change"),
        },
        "key_indicators": {
            "RSI": indicators.get("RSI"),
            "MACD.macd": indicators.get("MACD.macd"),
            "MACD.signal": indicators.get("MACD.signal"),
            "ADX": indicators.get("ADX"),
        },
    }


def get_technical_analysis(symbol, exchange, screener="america", interval="1d"):
    """Fetch TradingView's technical analysis for a symbol.

    Returns a dict with the recommendation summary, oscillators, moving
    averages, price, and key indicators. On failure, returns a dict with
    an "error" key instead of raising.
    """
    handler = TA_Handler(
        symbol=symbol,
        exchange=exchange,
        screener=screener,
        interval=interval,
    )
    try:
        analysis = handler.get_analysis()
    except Exception as exc:
        return {
            "symbol": symbol,
            "exchange": exchange,
            "error": str(exc),
        }

    return _format_analysis(analysis)


def get_multiple_technical_analysis(symbols, screener="america", interval="1d"):
    """Fetch TradingView's technical analysis for multiple symbols at once.

    Args:
        symbols: List of "EXCHANGE:SYMBOL" strings, e.g. ["NASDAQ:AAPL", "NASDAQ:TSLA"].
        screener: Market screener, e.g. "america", "crypto", "forex".
        interval: Candle interval, e.g. "1d".

    Returns a dict keyed by "EXCHANGE:SYMBOL". Each value is either a
    structured analysis dict (same shape as get_technical_analysis) or an
    "error" dict if that symbol couldn't be analyzed.
    """
    try:
        raw_results = _get_multiple_analysis(screener=screener, interval=interval, symbols=symbols)
    except Exception as exc:
        return {"error": str(exc)}

    results = {}
    for key, analysis in raw_results.items():
        if analysis is None:
            results[key] = {"error": "Exchange or symbol not found."}
        else:
            results[key] = _format_analysis(analysis)
    return results


def main():
    parser = argparse.ArgumentParser(
        description="Fetch TradingView technical analysis for a symbol."
    )
    parser.add_argument("symbol", help="Ticker symbol, e.g. AAPL")
    parser.add_argument("exchange", help="Exchange, e.g. NASDAQ")
    parser.add_argument(
        "--screener",
        default="america",
        help="Market screener, e.g. america, crypto, forex (default: america)",
    )
    parser.add_argument(
        "--interval",
        default="1d",
        help="Candle interval, e.g. 1m, 5m, 1h, 1d, 1W (default: 1d)",
    )
    args = parser.parse_args()

    result = get_technical_analysis(args.symbol, args.exchange, args.screener, args.interval)
    print(json.dumps(result, indent=2, default=str))
    sys.exit(1 if "error" in result else 0)


if __name__ == "__main__":
    main()
