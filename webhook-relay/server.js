require("dotenv").config();
const express = require("express");
const { placeMarketOrder, getOpenPositionQty } = require("./bybit");

const app = express();

// TradingView posts the alert_message as a raw string, often with a text/plain
// content-type, so accept any content-type here and JSON.parse it ourselves.
app.use(express.text({ type: "*/*", limit: "64kb" }));

const PORT = process.env.PORT || 3000;
const WEBHOOK_SECRET = process.env.WEBHOOK_SECRET;
const RISK_USDT = parseFloat(process.env.RISK_USDT || "0");
const FIXED_QTY = parseFloat(process.env.FIXED_QTY || "0");
const QTY_STEP = parseFloat(process.env.QTY_STEP || "0.001");
const QTY_DECIMALS = (QTY_STEP.toString().split(".")[1] || "").length;

function log(...args) {
    console.log(new Date().toISOString(), ...args);
}

function roundToStep(qty) {
    const stepped = Math.floor(qty / QTY_STEP) * QTY_STEP;
    return parseFloat(stepped.toFixed(QTY_DECIMALS));
}

function computeQty(price, stop) {
    if (RISK_USDT > 0 && price != null && stop != null) {
        const perUnitRisk = Math.abs(price - stop);
        if (perUnitRisk > 0) {
            return roundToStep(RISK_USDT / perUnitRisk);
        }
    }
    return roundToStep(FIXED_QTY);
}

app.get("/health", (req, res) => res.json({ ok: true }));

app.post("/hook/:secret", async (req, res) => {
    if (!WEBHOOK_SECRET || req.params.secret !== WEBHOOK_SECRET) {
        log("Rejected webhook: bad secret");
        return res.status(403).json({ error: "forbidden" });
    }

    let payload;
    try {
        payload = JSON.parse(req.body);
    } catch (err) {
        log("Rejected webhook: invalid JSON body:", req.body);
        return res.status(400).json({ error: "invalid JSON" });
    }

    log("Received:", payload);

    const { symbol, action, price, stop } = payload;
    if (!symbol || !action) {
        return res.status(400).json({ error: "symbol and action are required" });
    }

    try {
        let result;
        if (action === "buy") {
            const qty = computeQty(parseFloat(price), parseFloat(stop));
            if (qty <= 0) throw new Error("Computed qty <= 0, check RISK_USDT/FIXED_QTY/QTY_STEP");
            result = await placeMarketOrder({ symbol, side: "Buy", qty, reduceOnly: false });
        } else if (action === "sell") {
            const qty = computeQty(parseFloat(price), parseFloat(stop));
            if (qty <= 0) throw new Error("Computed qty <= 0, check RISK_USDT/FIXED_QTY/QTY_STEP");
            result = await placeMarketOrder({ symbol, side: "Sell", qty, reduceOnly: false });
        } else if (action === "close_long") {
            const pos = await getOpenPositionQty(symbol);
            if (pos.size > 0) {
                result = await placeMarketOrder({ symbol, side: "Sell", qty: pos.size, reduceOnly: true });
            } else {
                log("close_long requested but no open long position for", symbol);
            }
        } else if (action === "close_short") {
            const pos = await getOpenPositionQty(symbol);
            if (pos.size > 0) {
                result = await placeMarketOrder({ symbol, side: "Buy", qty: pos.size, reduceOnly: true });
            } else {
                log("close_short requested but no open short position for", symbol);
            }
        } else {
            return res.status(400).json({ error: `unknown action: ${action}` });
        }

        log("Order result:", result);
        res.json({ ok: true, result });
    } catch (err) {
        log("Order error:", err.message);
        res.status(500).json({ error: err.message });
    }
});

app.listen(PORT, () => {
    log(`Lexxie webhook relay listening on port ${PORT}`);
});
