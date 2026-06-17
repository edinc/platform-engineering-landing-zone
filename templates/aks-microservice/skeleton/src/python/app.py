from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import os
import structlog

logger = structlog.get_logger("${{ values.componentId }}")
REQUEST_COUNTS = {}


def record(status):
    REQUEST_COUNTS[status] = REQUEST_COUNTS.get(status, 0) + 1


def metrics():
    lines = [
        "# HELP http_server_requests_total Total HTTP requests by status code.",
        "# TYPE http_server_requests_total counter",
    ]
    for status, count in REQUEST_COUNTS.items():
        lines.append(
            'http_server_requests_total{service="${{ values.componentId }}",status="%s"} %s'
            % (status, count)
        )
    return "\n".join(lines) + "\n"


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/healthz":
            self.send_response(200)
            self.send_header("content-type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"status": "ok"}).encode())
            return
        if self.path == "/metrics":
            self.send_response(200)
            self.send_header("content-type", "text/plain; version=0.0.4")
            self.end_headers()
            self.wfile.write(metrics().encode())
            return

        logger.info("request received", path=self.path)
        record("200")
        self.send_response(200)
        self.send_header("content-type", "application/json")
        self.end_headers()
        self.wfile.write(
            json.dumps(
                {"service": "${{ values.componentId }}", "team": "${{ values.teamName }}"}
            ).encode()
        )


if __name__ == "__main__":
    port = int(os.getenv("PORT", "${{ values.port }}"))
    HTTPServer(("0.0.0.0", port), Handler).serve_forever()
