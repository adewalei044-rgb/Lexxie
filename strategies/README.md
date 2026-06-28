# Lexxie — Multi-Timeframe Gann + FVG Stop-Hunt Strategy

A TradingView **Pine Script v6** strategy that stacks the confluence you described:

| Step | Timeframe | Rule |
|------|-----------|------|
| 1. Trend | **4H** | Bias from the **200 MA** — price above = bullish, below = bearish. |
| 2. Structure | **1H** | A candle that closes **in the trend direction** with its **body closing beyond the previous candle's body** (displacement). |
| 3. Gann box | **1H** | Measure the qualifying candle **wick-low → wick-high**. Entry zones: **Long 0.50–0.75**, **Short 0.24–0.50**. |
| 4. Entry | **1m** | **Stop hunt** (liquidity sweep) **+ FVG** that is **in confluence with a 5m FVG**, and a **rejection candle inside the FVG** on the retracement. |

> **Run the strategy on the 1-minute chart.** The 5m / 1H / 4H data is pulled in
> automatically via `request.security`, so you only need one chart open.

---

## 1. Add the strategy to TradingView

1. Open TradingView → bottom panel **Pine Editor**.
2. Paste the contents of [`Lexxie_MTF_GannFVG_Strategy.pine`](./Lexxie_MTF_GannFVG_Strategy.pine).
3. Click **Add to chart**.
4. Set the chart timeframe to **1 minute**.

## 2. Configure the webhook

TradingView sends webhooks **from the alert dialog**, not from the script. The
script supplies the JSON payload via `alert_message`.

1. Click the alarm clock **➕ Create Alert** (or right-click the strategy → *Add alert*).
2. **Condition:** select **`Lexxie MTF Gann + FVG Stop-Hunt`**, and choose
   **`Order fills only`** (so it fires on actual entries/exits) — or use the
   `alertcondition` signals if you prefer signal-only alerts.
3. **Message:** leave it as `{{strategy.order.alert_message}}` — the script
   already builds the JSON.
4. Tick **Webhook URL** under *Notifications* and paste your endpoint:

   ```
   https://your-server.example.com/webhook/lexxie
   ```

   Common receivers:
   - Your own bot / server endpoint
   - 3Commas: `https://api.3commas.io/trade_signal/trading_view`
   - Other exchange-bridge services

5. **Create**.

> ⚠️ Replace the placeholder URL with **your** webhook endpoint. Never commit a
> real secret/token-bearing URL to the repo.

## 3. Webhook payload

Entries and exits emit JSON like:

```json
{
  "action": "buy",
  "symbol": "{{ticker}}",
  "price": "{{close}}",
  "tf": "{{interval}}",
  "time": "{{timenow}}",
  "strategy": "Lexxie_MTF",
  "sl": "…",
  "tp": "…"
}
```

`action` is one of `buy`, `sell`, `close`. Adjust the field names in the script
(`longMsg` / `shortMsg` / `exitMsg`) to match whatever your receiver expects.

---

## Inputs you can tune

- **Trend:** MA length (200), MA type (SMA/EMA), trend timeframe (4H).
- **1H structure:** structure timeframe (1H), toggle the body-break requirement.
- **Gann box:** the four retracement levels (long 0.50–0.75, short 0.24–0.50).
- **1m entry:** confluence timeframe (5m), stop-hunt lookback, FVG validity window.
- **Risk:** stop-loss %, risk:reward ratio (default **1:3**), toggle SL/TP.

## Stats table

A small table is drawn in the **top-right corner** showing live backtest stats:
**Win %**, **Win** trades, **Loss** trades, **Daily win**, **Daily loss**, and
**Drawdown** (max drawdown %). Daily win/loss reset at the start of each new
trading day.

## Notes & caveats

- This is the strict, fully-stacked interpretation of the rules — every
  condition must align on the same bar, so signals are **rare**. Loosen
  individual filters (e.g. disable the body-break, widen the FVG validity, or
  remove the stop-hunt requirement) while backtesting to see each leg's impact.
- `request.security` uses `lookahead_off` and only references **closed** higher
  timeframe candles (`[1]`/`[2]`) to avoid repainting.
- Always **backtest** and forward-test on paper before risking capital. This is
  educational tooling, not financial advice.
