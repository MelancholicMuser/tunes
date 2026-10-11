#!/usr/bin/env python3
"""Tiny fake LLM server for tests. Speaks Ollama (/api/tags, /api/generate) and
OpenAI-compatible (/v1/models, /v1/chat/completions). Usage: mock_llm.py PORT"""
import json, sys
from http.server import BaseHTTPRequestHandler, HTTPServer

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def _send(self, obj, code=200):
        body = json.dumps(obj).encode()
        self.send_response(code); self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body))); self.end_headers(); self.wfile.write(body)
    def do_GET(self):
        if self.path == '/api/tags': self._send({'models': [{'name': 'llama3.2:3b'}, {'name': 'mock:1b'}]})
        elif self.path == '/v1/models': self._send({'data': [{'id': 'local-model'}]})
        else: self._send({'error': 'not found'}, 404)
    def do_POST(self):
        n = int(self.headers.get('Content-Length', 0)); req = json.loads(self.rfile.read(n) or b'{}')
        if self.path == '/api/generate':
            if req.get('model') == 'missing:1b': return self._send({'error': 'model not found'}, 404)
            user, system = req.get('prompt', ''), req.get('system', '')
            self._send({'response': self.reply(system, user)})
        elif self.path == '/v1/chat/completions':
            m = req['messages']; auth = self.headers.get('Authorization', '')
            text = self.reply(m[0]['content'], m[1]['content'])
            self._send({'choices': [{'message': {'content': '<think>hmm</think>' + text + ' [auth:%s]' % auth}}]})
        else: self._send({'error': 'nope'}, 404)
    def reply(self, system, user):
        if 'connectivity test' in system: return 'ok'
        if 'search queries' in system: return '1. lofi beats\n2. - "rainy day jazz"\n3. ambient piano'
        if 'listening reports' in system: return 'AI-REPORT: top track noted. digest chars=%d' % len(user)
        if 'analyst' in system: return 'AI-ANSWER: ' + user.split('Question:')[-1].strip()
        return 'generic reply'

HTTPServer(('127.0.0.1', int(sys.argv[1])), H).serve_forever()
