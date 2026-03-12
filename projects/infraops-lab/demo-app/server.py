import os
import random
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest


FAILURE_RATE = float(os.getenv("FAILURE_RATE", "0.05"))

REQUESTS = Counter(
    "demo_app_requests_total",
    "Total HTTP requests served by the demo app",
    labelnames=("path", "status"),
)
LATENCY = Histogram(
    "demo_app_request_duration_seconds",
    "HTTP request latency (seconds)",
    labelnames=("path",),
    buckets=(0.01, 0.05, 0.1, 0.25, 0.5, 1, 2, 5),
)


class Handler(BaseHTTPRequestHandler):
    server_version = "demo-app/1.0"

    def log_message(self, fmt, *args):
        # Keep logs clean and structured-ish.
        message = fmt % args
        print(f'{{"ts":{time.time():.3f},"msg":{message!r},"path":{self.path!r}}}')

    def _write(self, status: int, body: bytes, content_type: str = "text/plain; charset=utf-8"):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):  # noqa: N802
        path = self.path.split("?", 1)[0]

        if path == "/health":
            with LATENCY.labels(path="/health").time():
                REQUESTS.labels(path="/health", status="200").inc()
                self._write(200, b"ok\n")
            return

        if path == "/metrics":
            body = generate_latest()
            REQUESTS.labels(path="/metrics", status="200").inc()
            self._write(200, body, CONTENT_TYPE_LATEST)
            return

        start = time.perf_counter()
        try:
            if random.random() < FAILURE_RATE:
                REQUESTS.labels(path="/", status="500").inc()
                self._write(500, b"simulated error\n")
                return

            REQUESTS.labels(path="/", status="200").inc()
            self._write(200, b"hello from demo-app\n")
        finally:
            LATENCY.labels(path="/").observe(time.perf_counter() - start)


if __name__ == "__main__":
    port = int(os.getenv("PORT", "8080"))
    print(f"Starting demo-app on 0.0.0.0:{port} (FAILURE_RATE={FAILURE_RATE})")
    HTTPServer(("0.0.0.0", port), Handler).serve_forever()
