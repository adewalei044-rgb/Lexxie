const crypto = require("crypto");

const BASE_URL = "https://api.bitget.com";
const PRODUCT_TYPE = process.env.BITGET_TESTNET === "true" ? "susdt-futures" : "USDT-FUTURES";
const MARGIN_COIN = "USDT";

function sign(timestamp, method, requestPath, body, apiSecret) {
    const prehash = timestamp + method.toUpperCase() + requestPath + body;
    return crypto.createHmac("sha256", apiSecret).update(prehash).digest("base64");
}

async function bitgetRequest(method, path, params) {
    const apiKey = process.env.BITGET_API_KEY;
    const apiSecret = process.env.BITGET_API_SECRET;
    const passphrase = process.env.BITGET_API_PASSPHRASE;
    if (!apiKey || !apiSecret || !passphrase) {
        throw new Error("BITGET_API_KEY / BITGET_API_SECRET / BITGET_API_PASSPHRASE not set in .env");
    }

    const timestamp = Date.now().toString();
    let requestPath = path;
    let body = "";

    if (method === "GET") {
        const qs = new URLSearchParams(params).toString();
        requestPath += qs ? `?${qs}` : "";
    } else {
        body = JSON.stringify(params);
    }

    const signature = sign(timestamp, method, requestPath, body, apiSecret);

    const headers = {
        "ACCESS-KEY": apiKey,
        "ACCESS-SIGN": signature,
        "ACCESS-TIMESTAMP": timestamp,
        "ACCESS-PASSPHRASE": passphrase,
        "Content-Type": "application/json",
        "locale": "en-US"
    };

    const res = await fetch(BASE_URL + requestPath, {
        method,
        headers,
        body: method === "GET" ? undefined : body
    });

    const json = await res.json();
    if (json.code !== "00000") {
        throw new Error(`Bitget API error ${json.code}: ${json.msg}`);
    }
    return json.data;
}

async function placeMarketOrder({ symbol, side, qty, reduceOnly }) {
    return bitgetRequest("POST", "/api/v2/mix/order/place-order", {
        symbol,
        productType: PRODUCT_TYPE,
        marginMode: "crossed",
        marginCoin: MARGIN_COIN,
        size: String(qty),
        side: side === "Buy" ? "buy" : "sell",
        tradeSide: reduceOnly ? "close" : "open",
        orderType: "market"
    });
}

async function getOpenPositionQty(symbol) {
    const result = await bitgetRequest("GET", "/api/v2/mix/position/single-position", {
        symbol,
        productType: PRODUCT_TYPE,
        marginCoin: MARGIN_COIN
    });
    const list = result || [];
    if (list.length === 0) return { size: 0, side: null };
    const pos = list[0];
    return { size: parseFloat(pos.total || "0"), side: pos.holdSide === "long" ? "Buy" : "Sell" };
}

module.exports = { placeMarketOrder, getOpenPositionQty };
