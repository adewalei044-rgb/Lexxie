// Every adapter in this folder exports the same two functions:
//   placeMarketOrder({ symbol, side: "Buy"|"Sell", qty, reduceOnly }) -> order result
//   getOpenPositionQty(symbol) -> { size, side }
// Add a new broker by dropping in another file here with that same shape and
// registering it below - server.js never needs to change.
const adapters = {
    bybit: require("./bybit"),
    bitget: require("./bitget")
};

const brokerName = (process.env.BROKER || "bybit").toLowerCase();
const adapter = adapters[brokerName];

if (!adapter) {
    throw new Error(`Unknown BROKER "${brokerName}". Supported: ${Object.keys(adapters).join(", ")}`);
}

module.exports = adapter;
module.exports.name = brokerName;
