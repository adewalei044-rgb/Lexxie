# TradingView Pine Script v6 Prompt — Multi-Strategy: Sweep Reversal & Trend Continuation (OB/FVG Entries)

Use this prompt with an AI code generator (or as your own build spec in the
Pine Editor) to produce a TradingView **Pine Script v6** indicator/strategy
for the setups described below.

The script houses **two independent strategies**, each with its own master
ON/OFF toggle in settings, and each strategy's individual timeframes also
get their own ON/OFF toggle buttons:

| Strategy | What it does | Master settings toggle | Default |
|----------|---------------|--------------------------|---------|
| 1. Sweep Reversal | Liquidity sweep of the previous candle by an opposite-colored candle, armed on the 3rd candle's open, entry via OB/FVG mitigation on a lower timeframe | "Enable Strategy 1: Sweep Reversal" | ON |
| 2. Trend Continuation | A trend-aligned candle that closes beyond the previous candle (continuation/breakout), armed on the next candle, entry via FVG reversal/pullback on a lower timeframe. Supports 1H→1M and 4H→5M pairs. | "Enable Strategy 2: Trend Continuation" | OFF |

Within Strategy 1, every individual timeframe also gets its own ON/OFF
toggle (as established previously):

| Timeframe | Role | Settings toggle | Default |
|-----------|------|------------------|---------|
| 4 Hour (4H) | Sweep detection | "4H Sweep Detection: ON/OFF" | ON |
| 5 Minute (5M) | Entry confirmation | "5M Entry Confirmation: ON/OFF" | ON |
| 1 Hour (1H) | Sweep detection | "1H Sweep Detection: ON/OFF" | OFF |
| 1 Minute (1M) | Entry confirmation | "1M Entry Confirmation: ON/OFF" | OFF |

A timeframe pair is only active when both its sweep-detection toggle and
its entry-confirmation toggle are switched ON.

Strategy 2 works the same way, and now supports **two** timeframe pairs
(same pattern as Strategy 1), each with its own individual ON/OFF toggle:

| Timeframe | Role | Settings toggle | Default |
|-----------|------|------------------|---------|
| 1 Hour (1H) | Trend candle detection | "1H Trend Candle Detection: ON/OFF" | ON |
| 1 Minute (1M) | FVG entry confirmation | "1M FVG Entry Confirmation: ON/OFF" | ON |
| 4 Hour (4H) | Trend candle detection | "4H Trend Candle Detection: ON/OFF" | OFF |
| 5 Minute (5M) | FVG entry confirmation | "5M FVG Entry Confirmation: ON/OFF" | OFF |

Same rule as Strategy 1: a Strategy 2 pair is only active when both its
trend-detection toggle and its entry-confirmation toggle are ON (e.g.
1H+1M = Pair A, 4H+5M = Pair B).

---

## Prompt

```
Write a TradingView Pine Script v6 indicator/strategy called
"Multi-Strategy: Sweep Reversal & Trend Continuation (OB/FVG)" with the
following logic:

================================================================
GLOBAL STRUCTURE
================================================================
- The script contains two independently toggleable strategies. Add a
  master boolean input for each:
    input.bool(true,  "Enable Strategy 1: Sweep Reversal")
    input.bool(false, "Enable Strategy 2: Trend Continuation")
  Only run a strategy's detection/entry logic while its master toggle is
  ON. Both strategies may run simultaneously without interfering with
  each other's state, drawings, or alerts. Tag every box, label, and
  alert with the strategy name/number so signals are distinguishable
  (e.g. "S1" vs "S2").
- Each strategy exposes its own timeframe pair, and every individual
  timeframe within each strategy gets its own boolean ON/OFF toggle
  input (not one combined switch per pair) plus a free-text timeframe
  input so it can be retuned without editing code.
- Pull all higher-timeframe candle data via request.security() with
  gaps=barmerge.gaps_off and lookahead=barmerge.lookahead_off to avoid
  repainting, for both strategies.

================================================================
STRATEGY 1 — SWEEP REVERSAL (existing logic, unchanged)
================================================================
TIMEFRAMES
    input.bool(true,  "4H Sweep Detection")      // ON by default
    input.bool(true,  "5M Entry Confirmation")   // ON by default
    input.bool(false, "1H Sweep Detection")      // OFF by default
    input.bool(false, "1M Entry Confirmation")   // OFF by default
  A pair is active when both its sweep-detection toggle and its
  entry-confirmation toggle are ON (e.g. 4H+5M = Pair A, 1H+1M = Pair B).
  Free-text timeframe inputs default to "240"/"5"/"60"/"1" respectively.

STEP 1 — LIQUIDITY SWEEP PAIR (run once per enabled timeframe pair, on
that pair's sweep-detection timeframe)
- Candle 1 (C1) = the reference/previous candle on that timeframe.
- Candle 2 (C2) = the candle immediately following C1.
- Sweep condition (bearish version): C2's low trades below C1's low
  AND C2 CLOSES below C1's low (a full-body close through the level,
  not just a wick).
- Sweep condition (bullish version): C2's high trades above C1's high
  AND C2 CLOSES above C1's high.
- Opposite-color rule: C1 and C2 must NOT be the same candle color. One
  must be bullish (close > open) and the other bearish (close < open),
  in either order. If both candles are the same color, reject the
  pattern.
- When both the sweep condition and the opposite-color rule are true,
  mark this as a valid "Sweep Signature" and store the sweep direction,
  the high/low of C1 and C2, and the bar index/time of C2.

STEP 2 — THIRD CANDLE TRIGGER
- Once a valid Sweep Signature is confirmed, arm the setup starting at
  the OPEN of the third candle (C3) on that pair's sweep-detection
  timeframe — the candle that opens immediately after C2 closes.
- From the open of C3 onward, watch that pair's entry timeframe for an
  entry confirmation (Step 3). Keep the setup "armed" until either a
  valid entry triggers or an invalidation occurs (price closes back
  beyond C2's sweep extreme, or a max number of entry-timeframe
  bars/hours elapse without a trigger — expose as a per-pair input).

STEP 3 — ENTRY CONFIRMATION (Order Block or Fair Value Gap, on the
pair's entry timeframe)
- Direction of the trade = the reversal direction implied by the sweep
  (swept and closed below C1's low → look for a BULLISH entry; swept
  and closed above C1's high → look for a BEARISH entry).
- Once C3 is open, detect either:
    a) Order Block (OB): the last opposite-colored candle immediately
       preceding a strong displacement move in the reversal direction.
       Mark its high/low as the OB zone.
    b) Fair Value Gap (FVG): a 3-candle imbalance where candle 1's
       high/low does not overlap candle 3's low/high in the reversal
       direction (classic ICT 3-candle FVG). Mark the gap as the FVG
       zone.
- Entry trigger: price returns to (mitigates) the OB or FVG zone after
  the initial displacement and shows a rejection (wick into the zone
  with a close back in the reversal direction, or an engulfing candle
  inside the zone).
- Only take the FIRST valid mitigation after C3 opens per pair; ignore
  further signals until invalidated or a trade is taken (toggle input:
  "one signal per sweep").

================================================================
STRATEGY 2 — TREND CONTINUATION + FVG REVERSAL ENTRY (new)
================================================================
TIMEFRAMES
    input.bool(true,  "1H Trend Candle Detection")     // ON by default
    input.bool(true,  "1M FVG Entry Confirmation")     // ON by default
    input.bool(false, "4H Trend Candle Detection")     // OFF by default
    input.bool(false, "5M FVG Entry Confirmation")     // OFF by default
  Each individually toggleable and retunable via free-text timeframe
  inputs, defaulting to "60" (1H), "1" (1M), "240" (4H), "5" (5M). A
  pair is active when both its trend-detection toggle and its
  entry-confirmation toggle are ON (1H+1M = Pair A, 4H+5M = Pair B).
  This strategy is only active while its master toggle ("Enable
  Strategy 2") AND at least one pair's two toggles are ON. Both pairs
  may run simultaneously, tracked independently (separate state,
  drawings, and alerts per pair, labeled "S2 1H/1M" vs "S2 4H/5M").

STEP 1 — TREND DIRECTION (run per active pair, on that pair's trend
-detection timeframe, e.g. 1H for Pair A or 4H for Pair B)
- Add a "Trend Detection Method" input with options:
    a) "Auto (EMA)": trend is bullish when close is above a
       user-configurable EMA (default length 50) on that timeframe,
       bearish when below.
    b) "Auto (Structure)": trend is bullish when price is making
       higher highs and higher lows over the last N swing points
       (expose N as an input, default 3), bearish when making lower
       highs and lower lows.
    c) "Manual": user explicitly selects Bullish or Bearish bias via a
       dropdown input, overriding automatic detection.
  Default method: "Auto (EMA)". Expose this setting per pair so, for
  example, Pair A (1H) and Pair B (4H) can use different EMA lengths.

STEP 2 — TREND CONTINUATION CANDLE (on that pair's trend-detection
timeframe)
- Candle X = a candle on that timeframe whose color matches the
  current trend direction (bullish candle, close > open, if trend is
  bullish; bearish candle, close < open, if trend is bearish).
- Continuation condition (bullish trend): Candle X CLOSES above the
  previous candle's high (full-body close beyond the prior candle,
  confirming displacement in the trend direction).
- Continuation condition (bearish trend): Candle X CLOSES below the
  previous candle's low.
- When both the trend-aligned color and the continuation-close
  condition are true, mark this as a valid "Continuation Signature" and
  store the trend direction, Candle X's high/low, and its bar
  index/time.
- Note: unlike Strategy 1, Candle X and the previous candle are NOT
  required to be opposite colors — this is a trend-following
  continuation pattern, not a reversal sweep.

STEP 3 — NEXT CANDLE TRIGGER
- Once a valid Continuation Signature is confirmed for a pair, arm that
  pair's setup starting at the OPEN of the very next candle on that
  pair's trend-detection timeframe (the candle immediately after
  Candle X closes).
- From that open onward, watch that pair's entry timeframe (1M for
  Pair A, 5M for Pair B) for a Fair Value Gap reversal/pullback entry
  (Step 4). Keep the setup "armed" until either a valid entry triggers
  or an invalidation occurs (price closes back through Candle X's open
  on the trend-detection timeframe, i.e. the continuation fails, or a
  max number of entry-timeframe bars/hours elapse without a trigger —
  expose as a per-pair input).

STEP 4 — FVG REVERSAL/PULLBACK ENTRY (on that pair's entry timeframe:
1M for Pair A, 5M for Pair B)
- Direction of the trade = the SAME direction as the trend/continuation,
  confirmed: trade to the UPSIDE (long) when the trend is bullish, and
  to the DOWNSIDE (short) when the trend is bearish. This is a
  trend-following pullback entry, NOT a fade of the continuation
  candle — bullish trend → BULLISH entry only; bearish trend → BEARISH
  entry only. Never take a counter-trend entry in Strategy 2.
- On the entry timeframe, once armed, detect a Fair Value Gap (3-candle
  imbalance, same definition as Strategy 1) that formed during the
  continuation move.
- Entry trigger: price pulls back ("reversal" in the small-timeframe
  sense — a retracement, not a trend reversal) into the FVG zone and
  shows a rejection back in the trend direction (wick into the zone
  with a close back in the trend direction, or a trend-aligned
  engulfing candle inside the zone).
- Only take the FIRST valid FVG mitigation after arming per pair;
  ignore further signals until invalidated or a trade is taken (toggle
  input: "one signal per continuation", applied per pair).

================================================================
GLOBAL FEATURES (apply across both strategies)
================================================================

SESSION FILTER (optional — off by default)
- input.bool(false, "Enable Session Filter"): when OFF, setups can
  detect/arm/enter at any time of day, exactly as described above.
- When ON, expose:
    - "Session Preset" dropdown: London / New York / Asian / London-NY
      Overlap / Custom.
    - "Custom Session" time-range input (Pine `input.session()`,
      e.g. "0800-1700") used when preset = Custom.
    - "Session Timezone" input (default = chart/exchange timezone,
      selectable, e.g. "America/New_York", "Etc/UTC").
- While the filter is ON, only allow ENTRY triggers (Strategy 1 Step 3
  mitigation, Strategy 2 Step 4 mitigation) to fire when the current
  entry-timeframe bar's time falls inside the active session window.
  Sweep/continuation detection and arming may still happen outside the
  session (so a setup can be armed overnight and simply wait for the
  next session to open before it's allowed to trigger).

BUY/SELL ENTRY LABELS
- On every confirmed entry, plot an explicit label.new at the entry
  bar: a green "BUY" label below the bar for long entries, a red
  "SELL" label above the bar for short entries, each showing the entry
  price and the originating strategy/pair tag (e.g. "BUY — S2 1H/1M").
  This is in addition to (or replaces) the generic entry
  triangle/label already described in Strategy 1/2 Step visuals.

PERFORMANCE STATS TABLE (top-right corner of the chart)
- input.bool(true, "Show Performance Table").
- Use table.new(position.top_right, ...) to render a small dashboard
  with these rows, updated live as trades resolve:
    - Win Rate (%)
    - Wins (count) / Losses (count)
    - Daily Win (count, resets at the start of each new calendar day
      in the chart's/exchange's timezone) / Daily Loss (count, same
      reset rule)
    - Drawdown (running max drawdown, expressed in R multiples and as
      a %, measured from the equity peak of the simulated R-based
      trade stream)
  Track every simulated trade internally as a "win" (target hit before
  stop) or "loss" (stop hit before target) using the fixed 1:2
  risk-to-reward defined below, incrementing running counters
  (var int) for total wins/losses and today's wins/losses, and
  updating a running peak-to-trough drawdown counter in R.
- The table must appear on the chart the instant the indicator/strategy
  loads — do not wait for the first signal or trade to draw it. Create
  the table object once with `var table perfTable = table.new(...)`
  outside any signal-dependent condition, and update/populate its
  cells on every bar where `barstate.islast` is true (so it always
  reflects the latest state and is visible immediately on load,
  showing zeros/dashes for any stat with no trades yet rather than
  staying blank).
- Table background color: RED by default (e.g. color.new(color.red, 0)
  for the table frame/bgcolor, or a slightly transparent red such as
  color.new(color.red, 70) so chart data stays visible underneath),
  with white/light text for contrast on every cell. Expose "Table
  Background Color" (default red) and "Table Text Color" (default
  white) as color inputs so the user can restyle without editing code.

RISK-TO-REWARD (applies to every strategy/pair)
- Default and intended risk-to-reward ratio is fixed at 1:2 (risk 1R
  to make 2R). Expose "Risk:Reward Multiple" as a numeric input
  (default 2.0) used both for (a) actual strategy.exit take-profit
  placement in Strategy mode, and (b) the simulated win/loss
  classification that feeds the Performance Stats Table.
- Stop loss reference: Strategy 1 uses the swept extreme (C2's wick);
  Strategy 2 uses Candle X's open or the FVG zone edge (as already
  defined in each strategy's CODE REQUIREMENTS). 1R = distance from
  entry to that stop; target = entry ± (1R × Risk:Reward Multiple).

BREAK-EVEN (optional — off by default)
- input.bool(false, "Enable Break-Even").
- input.float("Break-Even Trigger (R)", default 1.0): once an open
  trade has moved this many R multiples in favor of the entry, move
  the stop loss to the entry price (break-even) for that trade, both
  in Strategy mode (via strategy.exit modification / stop update) and
  in the simulated stream used for the Performance Stats Table (a
  break-even stop-out counts as neither a win nor a loss — track it as
  a separate "Break-Even" counter, not included in Win Rate).

MAX TRADES PER DAY (optional cap — off/unlimited by default)
- input.int("Max Trades Per Day", default 0, minimum 0): 0 means
  unlimited. When greater than 0, count entries taken today (across
  ALL enabled strategies/pairs combined, calendar day reset in the
  chart's/exchange's timezone) and block any further entry triggers
  once the count reaches this limit, resuming automatically at the
  start of the next day.

WEBHOOK-TRADABLE ALERTS (for automated execution via a broker/bot)
- input.bool(true, "Enable Webhook Alerts"): when ON, every entry (and
  exit) fires an alert whose message body is a JSON payload that a
  webhook-based trading bot (e.g. a broker API relay, 3Commas,
  Alertatron, or a custom receiver) can parse directly — not just a
  human-readable string.
- Default JSON template (fire via `alert(message, freq)` at the exact
  bar an entry/exit condition is confirmed):
    {
      "strategy": "{{strategy_tag}}",      // e.g. "S1" or "S2"
      "pair": "{{pair_tag}}",              // e.g. "4H/5M", "1H/1M"
      "action": "{{action}}",              // "buy", "sell", "close_long", "close_short"
      "symbol": "{{ticker}}",
      "price": {{close}},
      "stop_loss": {{stop_price}},
      "take_profit": {{target_price}},
      "risk_reward": {{rr_multiple}},
      "time": "{{time}}"
    }
  Expose the JSON template as a multi-line text input (`input.text_area`)
  pre-filled with the default above, so the user can adapt field names
  to whatever their specific webhook receiver expects, without editing
  code. Substitute the bracketed placeholders with the script's actual
  values (strategy/pair tag, computed stop/target prices, current
  bar's close/time/ticker) at alert time using string.format or string
  concatenation — Pine's built-in `{{ticker}}`/`{{close}}`/`{{time}}`
  placeholders may also be used directly inside the alert message
  string where TradingView supports them.
- Fire one webhook alert per entry (long/short) and, if Strategy mode
  with Break-Even/take-profit/stop-loss exits is enabled, one webhook
  alert per exit event too (target hit, stop hit, break-even move),
  each with its own "action" value, so the receiving bot can open and
  close positions automatically.
- Use `alert(message, freq=alert.freq_once_per_bar_close)` by default
  (confirmed-close firing, avoids duplicate/repainted signals on a
  live bar) with an input toggle "Fire Alerts Intra-bar" (bool, default
  false) to switch to `alert.freq_once_per_bar` for users who need
  faster execution and accept the repaint risk.
- If built in Strategy mode, also set `alert_message` on every
  `strategy.entry()` / `strategy.close()` / `strategy.exit()` call
  using the same JSON template, so TradingView's built-in "Order
  fills" alert option produces webhook-ready payloads too.

================================================================
VISUALS
================================================================
- Strategy 1: box/bracket around C1+C2 on the sweep-detection
  timeframe labeled "Sweep [S1 4H/5M]" or "Sweep [S1 1H/1M]" with an
  arrow showing swept direction; "Armed" label at C3's open; OB/FVG box
  on the entry timeframe.
- Strategy 2: box/bracket around the previous candle + Candle X on the
  trend-detection timeframe labeled "Continuation [S2 1H/1M]" or
  "Continuation [S2 4H/5M]" (per pair) with an arrow showing trend
  direction; "Armed" label at the next candle's open; FVG box on the
  entry timeframe.
- Every confirmed entry (either strategy) gets the BUY/SELL label
  described above at the entry bar.
- Performance Stats Table pinned to the top-right corner of the chart
  (see GLOBAL FEATURES), only drawn when "Show Performance Table" is
  ON.
- Use visually distinct colors/label prefixes ("S1" vs "S2") so signals
  from the two strategies are never confused, especially when both are
  enabled at once.

================================================================
ALERTS
================================================================
- Strategy 1: alertcondition() for "Sweep Signature Detected", "Setup
  Armed (C3 Open)", "OB/FVG Formed", "Entry Triggered" (long/short),
  each labeled with the active pair.
- Strategy 2: alertcondition() for "Continuation Signature Detected",
  "Setup Armed (Next Candle Open)", "FVG Formed", "Entry Triggered"
  (long/short), each labeled with the active pair ("S2 1H/1M" or
  "S2 4H/5M").
- Global: alertcondition() for "Break-Even Triggered" and "Max Trades
  Per Day Reached" (fires once when the daily cap is hit).
- When "Enable Webhook Alerts" is ON, every Entry Triggered alert (and
  every exit event in Strategy mode) additionally fires via `alert()`
  with the JSON payload described in GLOBAL FEATURES → WEBHOOK-TRADABLE
  ALERTS, so the same signal can drive an automated broker/bot through
  a TradingView webhook URL, not just a human notification.

================================================================
INPUTS (user-configurable, grouped by strategy)
================================================================
Strategy 1:
- "Enable Strategy 1: Sweep Reversal" (bool, default true)
- "4H Sweep Detection: ON/OFF" (bool, default ON) + timeframe text
  input (default "240")
- "5M Entry Confirmation: ON/OFF" (bool, default ON) + timeframe text
  input (default "5")
- "1H Sweep Detection: ON/OFF" (bool, default OFF) + timeframe text
  input (default "60")
- "1M Entry Confirmation: ON/OFF" (bool, default OFF) + timeframe text
  input (default "1")
- Require full-body close through swept level (bool, default true)
- Use Order Block detection (bool, default true)
- Use Fair Value Gap detection (bool, default true)
- Max bars/hours to wait for entry after arming (int, per pair)

Strategy 2:
- "Enable Strategy 2: Trend Continuation" (bool, default false)
- "1H Trend Candle Detection: ON/OFF" (bool, default ON) + timeframe
  text input (default "60")
- "1M FVG Entry Confirmation: ON/OFF" (bool, default ON) + timeframe
  text input (default "1")
- "4H Trend Candle Detection: ON/OFF" (bool, default OFF) + timeframe
  text input (default "240")
- "5M FVG Entry Confirmation: ON/OFF" (bool, default OFF) + timeframe
  text input (default "5")
- "Trend Detection Method" (dropdown: Auto EMA / Auto Structure /
  Manual, default Auto EMA) — exposed per pair
- EMA length for trend filter (int, default 50, used when method =
  Auto EMA) — exposed per pair
- Swing lookback N for structure trend filter (int, default 3, used
  when method = Auto Structure) — exposed per pair
- Manual trend bias (dropdown: Bullish / Bearish, used when method =
  Manual) — exposed per pair
- Require full-body close beyond previous candle (bool, default true)
- Max bars/hours to wait for entry after arming (int, per pair)

Shared (global, apply across both strategies):
- Colors for bullish/bearish zones and labels, with separate color sets
  per strategy/pair so all active signals stay visually distinct.
- "Enable Session Filter" (bool, default false)
  - "Session Preset" (dropdown: London / New York / Asian / London-NY
    Overlap / Custom, default London)
  - "Custom Session" (session time-range input, used when preset =
    Custom)
  - "Session Timezone" (string input, default chart timezone)
- "Show Performance Table" (bool, default true) — renders the Win
  Rate / Wins / Losses / Daily Win / Daily Loss / Drawdown table in
  the top-right corner
  - "Table Background Color" (color, default red)
  - "Table Text Color" (color, default white)
- "Risk:Reward Multiple" (float, default 2.0, i.e. 1:2 risk-to-reward)
- "Enable Break-Even" (bool, default false)
  - "Break-Even Trigger (R)" (float, default 1.0)
- "Max Trades Per Day" (int, default 0 = unlimited), counted across
  all enabled strategies/pairs combined
- "Enable Webhook Alerts" (bool, default true)
  - "Webhook JSON Template" (text area, pre-filled with the default
    JSON payload shown in GLOBAL FEATURES → WEBHOOK-TRADABLE ALERTS)
  - "Fire Alerts Intra-bar" (bool, default false; ON uses
    alert.freq_once_per_bar for faster execution and repaint risk,
    OFF uses alert.freq_once_per_bar_close for confirmed signals)

================================================================
CODE REQUIREMENTS
================================================================
- Must declare //@version=6 and use current Pine Script v6 syntax
  (updated request.security() usage, box.new/label.new for drawings,
  input.* namespace functions).
- Use request.security() with gaps=barmerge.gaps_off and
  lookahead=barmerge.lookahead_off for all higher-timeframe pulls (4H,
  1H) to avoid repainting.
- Keep state using var/varip variables to track each strategy's/pair's
  current Signature, armed status, and OB/FVG zone across bars, fully
  independently (separate state for each of Strategy 1's pairs and
  each of Strategy 2's pairs, so enabling multiple simultaneously never
  cross-contaminates signals).
- Add clear inline comments only where the logic is non-obvious (e.g.
  why lookahead is disabled, why full-body close is required, why
  Strategy 2 trades WITH the trend while Strategy 1 trades AGAINST the
  sweep).
- Optimize for both overlay indicator use and strategy.entry/exit calls
  if built as a strategy (toggle: "Indicator mode" vs "Strategy mode"
  using strategy.* calls with basic risk management — Strategy 1: stop
  loss at the swept extreme; Strategy 2: stop loss at Candle X's open
  or the FVG zone edge; both with a user-defined take-profit R
  multiple).
- The Performance Stats Table must be created once with `var table` at
  the top level (not inside an `if` tied to a signal) and redrawn on
  every `barstate.islast` bar, so it is visible immediately when the
  script is first added to the chart — never blank or missing until a
  trade occurs.
```

---

## Notes on assumptions made when clarifying your description

**Strategy 1 (Sweep Reversal):**
- **"Previous candle sweep, next candle closes below the previous
  candle"** was interpreted as: the candle after the reference candle
  wicks through *and closes beyond* the reference candle's high/low —
  a full-body break, not just a wicking rejection.
- **"Previous and new candle must not be same... bullish and bearish or
  bearish and bullish"** was interpreted as: the two candles in the
  sweep pair must be opposite colors.
- **"Third opening candle"** was interpreted as the open of the candle
  immediately following the 2-candle sweep pattern.
- **"Reversal of the sweep"** was interpreted as trading back in the
  *opposite* direction of the sweep (fading the stop-hunt).

**Strategy 2 (Trend Continuation, new):**
- **"Bullish or bearish candle on a trend closes above the previous
  candle"** was interpreted as: a candle matching the prevailing trend
  direction that closes beyond (above the high, for a bullish trend;
  below the low, for a bearish trend) the prior candle — a
  displacement/continuation candle. Since you didn't specify how
  "trend" is determined, the prompt exposes it as a configurable input
  (EMA-based, swing-structure-based, or manual bias) so you can pick
  the definition that matches your usual analysis.
- **"Trade next candle reversal ... according to trend to the upside or
  downside"** — CONFIRMED (not just assumed): once the continuation
  candle closes and the next candle opens on the trend-detection
  timeframe, drop to the entry timeframe and wait for price to pull
  back ("reversal" here meaning a short-term retracement, not a full
  trend reversal) into a Fair Value Gap, then enter WITH the trend on
  rejection from that FVG — long/upside entries only in a bullish
  trend, short/downside entries only in a bearish trend, never a
  counter-trend fade. This is the opposite trade direction from
  Strategy 1 (which fades/reverses the sweep).
- The **4H trend candle / 5M FVG entry** and **1H trend candle / 1M FVG
  entry** requests were both treated as selectable pairs inside the
  same Strategy 2 (Pair A = 1H/1M, Pair B = 4H/5M), running identical
  continuation + upside/downside pullback logic, just on different
  timeframes — rather than as separate strategies, since the rules
  described are the same.

If any of these assumptions doesn't match your intent — particularly
how "trend" should be defined for Strategy 2, or whether the FVG entry
should instead fade the continuation candle rather than ride the trend
— let me know and I'll adjust the prompt.
