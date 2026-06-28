import unittest
from unittest.mock import patch

from tv_health_check import check_port, tv_health_check


class CheckPortTests(unittest.TestCase):
    @patch("tv_health_check.socket.create_connection")
    def test_open_port_returns_latency(self, mock_connect):
        mock_connect.return_value.__enter__.return_value = None
        is_open, latency_ms = check_port("10.0.0.5", 8001, timeout=1.0)
        self.assertTrue(is_open)
        self.assertIsNotNone(latency_ms)

    @patch("tv_health_check.socket.create_connection", side_effect=OSError)
    def test_closed_port_returns_false(self, mock_connect):
        is_open, latency_ms = check_port("10.0.0.5", 8001, timeout=1.0)
        self.assertFalse(is_open)
        self.assertIsNone(latency_ms)


class TvHealthCheckTests(unittest.TestCase):
    @patch("tv_health_check.check_port")
    def test_healthy_when_any_port_open(self, mock_check_port):
        mock_check_port.side_effect = [(False, None), (True, 12.5)]
        result = tv_health_check("10.0.0.5", ports=[443, 8001])
        self.assertEqual(result["status"], "healthy")
        self.assertEqual(result["latency_ms"], 12.5)

    @patch("tv_health_check.check_port")
    def test_unreachable_when_no_ports_open(self, mock_check_port):
        mock_check_port.return_value = (False, None)
        result = tv_health_check("10.0.0.5", ports=[443, 8001])
        self.assertEqual(result["status"], "unreachable")
        self.assertIsNone(result["latency_ms"])


if __name__ == "__main__":
    unittest.main()
