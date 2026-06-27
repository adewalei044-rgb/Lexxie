#!/usr/bin/env python3
"""MCP server exposing TradingView technical analysis as a tool for Claude."""

from mcp.server.fastmcp import FastMCP

from tradingview_data import get_technical_analysis

mcp = FastMCP("tradingview")


@mcp.tool()
def get_analysis(symbol: str, exchange: str, screener: str = "america", interval: str = "1d") -> dict:
    """Get TradingView technical analysis (price, indicators, recommendation) for a symbol.

    Args:
        symbol: Ticker symbol, e.g. "AAPL", "BTCUSDT".
        exchange: Exchange, e.g. "NASDAQ", "BINANCE".
        screener: Market screener, e.g. "america", "crypto", "forex" (default: "america").
        interval: Candle interval, e.g. "1m", "5m", "1h", "1d", "1W" (default: "1d").
    """
    return get_technical_analysis(symbol, exchange, screener, interval)


if __name__ == "__main__":
    mcp.run()
