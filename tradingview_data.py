#!/usr/bin/env python3
"""Fetch technical analysis data from TradingView for a given symbol."""

import argparse
import json
import sys

from tradingview_ta import TA_Handler


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
