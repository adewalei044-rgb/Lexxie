const crypto = require("crypto");

const BASE_URL = process.env.BYBIT_TESTNET === "true"
    ? "https://api-testnet.bybit.com"
    : "https://api.bybit.com";

const RECV_WINDOW = "5000";

function sign(timestamp, apiKey, apiSecret, payload) {
    const prehash = timestamp + apiKey + RECV_WINDOW + payload;
    return crypto.createHmac("sha256", apiSecret).update(prehash).digest("hex");
}

async function bybitRequest(method, path, params) {
    const apiKey = process.env.BYBIT_API_KEY;
    const apiSecret = process.env.BYBIT_API_SECRET;
    if (!apiKey || !apiSecret) {
        throw new Error("BYBIT_API_KEY / BYBIT_API_SECRET not set in .env");
    }

    const timestamp = Date.now().toString();
    let url = BASE_URL + path;
    let body = "";

    if (method === "GET") {
        const qs = new URLSearchParams(params).toString();
        url += qs ? `?${qs}` : "";
        body = qs;
    } else {
        body = JSON.stringify(params);
    }

    const signature = sign(timestamp, apiKey, apiSecret, body);

    const headers = {
        "X-BAPI-API-KEY": apiKey,
        "X-BAPI-SIGN": signature,
        "X-BAPI-SIGN-TYPE": "2",
        "X-BAPI-TIMESTAMP": timestamp,
        "X-BAPI-RECV-WINDOW": RECV_WINDOW,
        "Content-Type": "application/json"
    };

    const res = await fetch(url, {
        method,
        headers,
        body: method === "GET" ? undefined : body
    });

    const json = await res.json();
    if (json.retCode !== 0) {
        throw new Error(`Bybit API error ${json.retCode}: ${json.retMsg}`);
    }
    return json.result;
}

const CATEGORY = process.env.BYBIT_CATEGORY || "linear";

async function placeMarketOrder({ symbol, side, qty, reduceOnly }) {
    return bybitRequest("POST", "/v5/order/create", {
        category: CATEGORY,
        symbol,
        side,
        orderType: "Market",
        qty: String(qty),
        reduceOnly: !!reduceOnly,
        timeInForce: "IOC"
    });
}

async function getOpenPositionQty(symbol) {
    const result = await bybitRequest("GET", "/v5/position/list", {
        category: CATEGORY,
        symbol
    });
    const list = result.list || [];
    if (list.length === 0) return { size: 0, side: null };
    const pos = list[0];
    return { size: parseFloat(pos.size || "0"), side: pos.side };
}

module.exports = { placeMarketOrder, getOpenPositionQty };
