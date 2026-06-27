import unittest
from unittest.mock import MagicMock, patch

from tradingview_data import get_technical_analysis


def make_fake_analysis():
    analysis = MagicMock()
    analysis.symbol = "AAPL"
    analysis.exchange = "NASDAQ"
    analysis.screener = "america"
    analysis.interval = "1d"
    analysis.time = "2026-06-27 00:00:00"
    analysis.summary = {"RECOMMENDATION": "BUY", "BUY": 10, "SELL": 2, "NEUTRAL": 5}
    analysis.oscillators = {"RECOMMENDATION": "NEUTRAL"}
    analysis.moving_averages = {"RECOMMENDATION": "BUY"}
    analysis.indicators = {
        "close": 195.5,
        "open": 193.2,
        "high": 196.0,
        "low": 192.8,
        "volume": 1000000,
        "change": 1.2,
        "RSI": 55.3,
        "MACD.macd": 0.5,
        "MACD.signal": 0.3,
        "ADX": 20.1,
    }
    return analysis


class GetTechnicalAnalysisTests(unittest.TestCase):
    @patch("tradingview_data.TA_Handler")
    def test_returns_structured_result_on_success(self, mock_handler_cls):
        mock_handler_cls.return_value.get_analysis.return_value = make_fake_analysis()

        result = get_technical_analysis("AAPL", "NASDAQ")

        self.assertEqual(result["symbol"], "AAPL")
        self.assertEqual(result["summary"]["RECOMMENDATION"], "BUY")
        self.assertEqual(result["price"]["close"], 195.5)
        self.assertEqual(result["key_indicators"]["RSI"], 55.3)
        self.assertNotIn("error", result)

    @patch("tradingview_data.TA_Handler")
    def test_returns_error_on_failure(self, mock_handler_cls):
        mock_handler_cls.return_value.get_analysis.side_effect = Exception("Exchange or symbol not found.")

        result = get_technical_analysis("BADSYMBOL", "NASDAQ")

        self.assertEqual(result["symbol"], "BADSYMBOL")
        self.assertIn("error", result)
        self.assertIn("not found", result["error"])

    @patch("tradingview_data.TA_Handler")
    def test_passes_screener_and_interval_through(self, mock_handler_cls):
        mock_handler_cls.return_value.get_analysis.return_value = make_fake_analysis()

        get_technical_analysis("BTCUSDT", "BINANCE", screener="crypto", interval="1h")

        mock_handler_cls.assert_called_once_with(
            symbol="BTCUSDT", exchange="BINANCE", screener="crypto", interval="1h"
        )


if __name__ == "__main__":
    unittest.main()
