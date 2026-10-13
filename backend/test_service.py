import os
import unittest
from unittest.mock import patch
from fastapi.testclient import TestClient
from main import app

class ServiceTests(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app)
        self.env = patch.dict(os.environ, {'LLM_API_KEY': '', 'LLM_API_BASE': '', 'LLM_MODEL': ''})
        self.env.start()
    def tearDown(self):
        self.env.stop()
    def test_health(self):
        self.assertEqual(self.client.get('/health').json()['core_game'], 'offline')
    def test_offline_memory(self):
        result = self.client.post('/memory/reconstruct', json={'memory_ids': [0, 3]}).json()
        self.assertEqual(result['source'], 'fallback')
        self.assertTrue(result['text'])
    def test_invalid_ids(self):
        for ids in [[], [-1], [12], list(range(13))]:
            self.assertEqual(self.client.post('/memory/reconstruct', json={'memory_ids': ids}).status_code, 422)
    def test_endings(self):
        for name in ['eden', 'regeneration']:
            value = self.client.post('/ending/generate', json={'ending': name, 'memories_found': 6}).json()
            self.assertTrue(value['message'])
            self.assertEqual(value['source'], 'fallback')
        self.assertEqual(self.client.post('/ending/generate', json={'ending': 'unknown', 'memories_found': 13}).status_code, 422)
    def test_provider_failure_falls_back(self):
        with patch.dict(os.environ, {'LLM_API_KEY': 'test-only', 'LLM_API_BASE': 'https://example.invalid/v1', 'LLM_MODEL': 'test'}):
            with patch('urllib.request.urlopen', side_effect=TimeoutError):
                value = self.client.post('/memory/reconstruct', json={'memory_ids': [1]}).json()
                self.assertEqual(value['source'], 'fallback')
    def test_live_provider_response(self):
        from unittest.mock import MagicMock
        response=MagicMock()
        response.__enter__.return_value.read.return_value=b'{"choices":[{"message":{"content":"A quiet memory"}}]}'
        with patch.dict(os.environ, {'LLM_API_KEY': 'test-only', 'LLM_API_BASE': 'https://example.invalid/v1', 'LLM_MODEL': 'test'}):
            with patch('urllib.request.urlopen', return_value=response):
                value = self.client.post('/memory/reconstruct', json={'memory_ids': [1]}).json()
                self.assertEqual(value['source'], 'llm')
                self.assertEqual(value['text'], 'A quiet memory')

if __name__ == '__main__':
    unittest.main()
