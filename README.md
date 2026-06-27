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
Code automatically; it exposes one tool, `get_analysis(symbol, exchange,
screener="america", interval="1d")`.

Run it directly without Claude:

```
.venv/bin/python tradingview_data.py AAPL NASDAQ
```
