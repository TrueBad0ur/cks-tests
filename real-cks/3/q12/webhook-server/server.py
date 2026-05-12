#!/usr/bin/env python3
import json
import ssl
import os
from http.server import HTTPServer, BaseHTTPRequestHandler


BLOCKED_PATTERNS = os.environ.get("BLOCKED_PATTERNS", "danger-danger").split(",")


class ImagePolicyHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        body = json.loads(self.rfile.read(length))

        images = []
        for c in body.get("spec", {}).get("containers", []):
            images.append(c["image"])
        for c in body.get("spec", {}).get("initContainers", []):
            images.append(c["image"])

        blocked = [img for img in images if any(p in img for p in BLOCKED_PATTERNS)]
        allowed = len(blocked) == 0

        reason = f"Images containing {BLOCKED_PATTERNS[0]} are not allowed" if blocked else "all images allowed"
        print(f"POST request check image name: {images}")
        if blocked:
            print("POST image name FORBIDDEN")

        response = {
            "apiVersion": "imagepolicy.k8s.io/v1alpha1",
            "kind": "ImageReview",
            "status": {
                "allowed": allowed,
                "reason": reason,
            },
        }
        body_bytes = json.dumps(response).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body_bytes)))
        self.end_headers()
        self.wfile.write(body_bytes)

    def log_message(self, fmt, *args):
        print(fmt % args)


def main():
    port = int(os.environ.get("PORT", "443"))
    tls_cert = os.environ.get("TLS_CERT", "")
    tls_key = os.environ.get("TLS_KEY", "")

    server = HTTPServer(("0.0.0.0", port), ImagePolicyHandler)

    if tls_cert and tls_key:
        ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        ctx.load_cert_chain(tls_cert, tls_key)
        server.socket = ctx.wrap_socket(server.socket, server_side=True)
        print(f"Listening on :{port} (TLS)")
    else:
        print(f"Listening on :{port} (plain HTTP)")

    server.serve_forever()


if __name__ == "__main__":
    main()
