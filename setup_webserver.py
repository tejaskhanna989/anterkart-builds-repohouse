import paramiko
import os

VPS_HOST = "91.108.107.50"
VPS_PORT = 65002
VPS_USER = "u881842192"
VPS_PASSWORD = "Imnotbadbtw@idunnowhatyouthink1"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(VPS_HOST, port=65002, username=VPS_USER, password="Imnotbadbtw@idunnowhatyouthink1", timeout=30)

def run_cmd(cmd):
    stdin, stdout, stderr = ssh.exec_command(cmd)
    exit_status = stdout.channel.recv_exit_status()
    out = stdout.read().decode()
    err = stderr.read().decode()
    if out: print(f"OUT: {out}")
    if err: print(f"ERR: {err}")
    return exit_status

print("=== Checking available tools ===")
run_cmd("which wget curl python3 python python2 busybox")
run_cmd("ls /usr/bin/ | head -30")

# Check if we can download static nginx binary
print("\n=== Downloading static nginx binary ===")
run_cmd("cd /tmp && wget -q https://nginx.org/download/nginx-1.25.3.tar.gz 2>&1 || curl -sL https://nginx.org/download/nginx-1.25.3.tar.gz -o nginx-1.25.3.tar.gz 2>&1")

# Check if we can compile nginx
run_cmd("which gcc make")

# Try to install a simple Python HTTP server with directory listing
print("\n=== Setting up Python HTTP server with directory listing ===")
http_server_script = '''#!/usr/bin/env python3
import http.server
import socketserver
import os
import urllib.parse

class APKHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory="/home/u881842192/otamzo-download-page", **kwargs)
    
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        super().end_headers()
    
    def guess_type(self, path):
        if path.endswith('.apk'):
            return 'application/vnd.android.package-archive'
        return super().guess_type(path)

if __name__ == "__main__":
    PORT = 80
    os.chdir("/home/u881842192/otamzo-download-page")
    with socketserver.TCPServer(("", PORT), APKHandler) as httpd:
        print(f"Serving at port {PORT}")
        httpd.serve_forever()
'''

# Write and run the HTTP server
stdin, stdout, stderr = ssh.exec_command("cat > /home/u881842192/otamzo_server.py << 'EOF'\nimport http.server\nimport socketserver\nimport os\nimport socketserver\n\nclass APKHandler(http.server.SimpleHTTPRequestHandler):\n    def __init__(self, *args, **kwargs):\n        super().__init__(*args, directory=\"/home/u881842192/otamzo-download-page\", **kwargs)\n    \n    def end_headers(self):\n        self.send_header('Access-Control-Allow-Origin', '*')\n        super().end_headers()\n    \n    def guess_type(self, path):\n        if path.endswith('.apk'):\n            return 'application/vnd.android.package-archive'\n        return super().guess_type(path)\n\nif __name__ == \"__main__\":\n    PORT = 80\n    os.chdir(\"/home/u881842192/otamzo-download-page\")\n    with socketserver.TCPServer((\"\", PORT), APKHandler) as httpd:\n        print(f\"Serving at port {PORT}\")\n        httpd.serve_forever()\nEOF")
print("Server script written")

# Run server in background
stdin, stdout, stderr = ssh.exec_command("nohup python3 /home/u881842192/otamzo_server.py > /home/u881842192/otamzo_server.log 2>&1 &")
print("Server started in background")

# Check if running
import time
time.sleep(2)
stdin, stdout, stderr = ssh.exec_command("ps aux | grep otamzo_server")
print(stdout.read().decode())

# Test if port 80 is listening
stdin, stdout, stderr = ssh.exec_command("netstat -tlnp 2>/dev/null | grep :80 || ss -tlnp 2>/dev/null | grep :80")
print("Port 80 status:")
print(stdout.read().decode())

ssh.close()
