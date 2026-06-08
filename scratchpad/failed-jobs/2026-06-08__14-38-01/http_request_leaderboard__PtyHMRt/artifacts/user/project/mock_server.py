import json
import time
from http.server import HTTPServer, BaseHTTPRequestHandler

# Keep track of request counts and timestamps
request_log = []
top_request_count = 0
submit_request_count = 0

class MockLeaderboardHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        # Suppress default logging to keep output clean
        pass

    def do_GET(self):
        global top_request_count
        timestamp = time.time()
        request_log.append(("GET", self.path, timestamp))
        print(f"[Server] GET {self.path} at {timestamp:.4f}")

        if self.path.startswith("/top"):
            top_request_count += 1
            if top_request_count <= 2:
                # Return failure for first 2 attempts
                self.send_response(500)
                self.send_header("Content-Type", "application/json")
                response_bytes = json.dumps({"error": "Internal Server Error"}).encode()
                self.send_header("Content-Length", str(len(response_bytes)))
                self.end_headers()
                self.wfile.write(response_bytes)
                print(f"[Server] GET {self.path} -> 500 (Attempt {top_request_count})")
            else:
                # Return success on 3rd attempt (retry 2)
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                response = [
                    {"name": "Alice", "score": 100},
                    {"name": "Bob", "score": 90}
                ]
                response_bytes = json.dumps(response).encode()
                self.send_header("Content-Length", str(len(response_bytes)))
                self.end_headers()
                self.wfile.write(response_bytes)
                print(f"[Server] GET {self.path} -> 200 (Attempt {top_request_count})")
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        global submit_request_count
        timestamp = time.time()
        request_log.append(("POST", self.path, timestamp))
        print(f"[Server] POST {self.path} at {timestamp:.4f}")

        if self.path == "/submit":
            submit_request_count += 1
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length).decode()
            print(f"[Server] POST {self.path} body: {body}")

            if submit_request_count <= 2:
                # Return failure for first 2 attempts
                self.send_response(500)
                self.send_header("Content-Type", "application/json")
                response_bytes = json.dumps({"error": "Internal Server Error"}).encode()
                self.send_header("Content-Length", str(len(response_bytes)))
                self.end_headers()
                self.wfile.write(response_bytes)
                print(f"[Server] POST {self.path} -> 500 (Attempt {submit_request_count})")
            else:
                # Return success on 3rd attempt (retry 2)
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                response = {"rank": 3}
                response_bytes = json.dumps(response).encode()
                self.send_header("Content-Length", str(len(response_bytes)))
                self.end_headers()
                self.wfile.write(response_bytes)
                print(f"[Server] POST {self.path} -> 200 (Attempt {submit_request_count})")
        else:
            self.send_response(404)
            self.end_headers()

def run(server_class=HTTPServer, handler_class=MockLeaderboardHandler, port=8765):
    server_address = ('', port)
    httpd = server_class(server_address, handler_class)
    print(f"Starting mock server on port {port}...")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        httpd.server_close()

if __name__ == '__main__':
    run()
