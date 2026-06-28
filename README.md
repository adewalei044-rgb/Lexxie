# adewalei044-rgb
Just getting it done

## TradingView MCP server

Lets Claude query TradingView technical analysis (price, indicators,
recommendation) for a symbol.

Setup:

```
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

`.mcp.json` registers the server (`tradingview_mcp_server.py`) for Claude
Code automatically; it exposes two tools:

- `get_analysis(symbol, exchange, screener="america", interval="1d")` for one symbol.
- `get_multiple_analysis(symbols, screener="america", interval="1d")` for several
  at once, e.g. `["NASDAQ:AAPL", "NASDAQ:TSLA"]`.

Run it directly without Claude:

```
.venv/bin/python tradingview_data.py AAPL NASDAQ
```
