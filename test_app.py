import unittest
from fastapi.testclient import TestClient
from app import app

client = TestClient(app)

class TestCyberBackend(unittest.TestCase):
    def test_stats_endpoint(self):
        response = client.get("/api/stats")
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn("cpu_percent", data)
        self.assertIn("ram_percent", data)
        self.assertIn("uptime_formatted", data)

    def test_chat_fallback(self):
        response = client.post("/api/chat", json={"message": "Hallo CYBER"})
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn("reply", data)

    def test_code_execution(self):
        response = client.post("/api/execute-code", json={"code": "print('CYBER TEST')" if True else ""})
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertTrue(data["success"])
        self.assertIn("CYBER TEST", data["stdout"])

    def test_system_commands(self):
        response = client.get("/api/system/commands")
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn("commands", data)

if __name__ == "__main__":
    unittest.main()
