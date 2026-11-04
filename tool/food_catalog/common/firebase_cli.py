"""Use Firebase CLI's authenticated MCP interface without exposing credentials."""

import json
import os
import select
import subprocess
import time


class FirebaseCLI:
    def __init__(self, project, directory):
        self.process = subprocess.Popen(
            ["firebase", "mcp", "--dir", str(directory), "--only", "core,firestore"],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
        )
        self.buffer = b""
        self.sequence = 0
        try:
            self.request("initialize", {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "food-catalog-review", "version": "1"}})
            self.send({"jsonrpc": "2.0", "method": "notifications/initialized"})
        except BaseException:
            self.close()
            raise

    def send(self, message):
        self.process.stdin.write((json.dumps(message) + "\n").encode())
        self.process.stdin.flush()

    def request(self, method, params, timeout=60):
        self.sequence += 1
        request_id = self.sequence
        self.send({"jsonrpc": "2.0", "id": request_id, "method": method, "params": params})
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if b"\n" not in self.buffer:
                if not select.select([self.process.stdout], [], [], max(0, deadline - time.monotonic()))[0]:
                    break
                chunk = os.read(self.process.stdout.fileno(), 65536)
                if not chunk:
                    raise RuntimeError("Firebase CLI closed its connection")
                self.buffer += chunk
                continue
            line, self.buffer = self.buffer.split(b"\n", 1)
            try:
                message = json.loads(line)
            except (ValueError, UnicodeDecodeError):
                continue
            if message.get("id") == request_id:
                if "error" in message:
                    raise RuntimeError(str(message["error"]))
                return message["result"]
        raise TimeoutError(f"Firebase CLI timed out during {method}")

    def close(self):
        if self.process.poll() is None:
            self.process.terminate()
            try:
                self.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait()

    def call_read_tool(self, name, arguments):
        allowed = {"firestore_list_collections", "firestore_list_documents", "firestore_get_document", "firestore_query_collection", "firebase_get_security_rules", "firebase_get_project", "firestore_get_database", "firestore_list_indexes"}
        if name not in allowed:
            raise ValueError(f"Tool is outside the read-only allowlist: {name}")
        return self.request("tools/call", {"name": name, "arguments": arguments})
