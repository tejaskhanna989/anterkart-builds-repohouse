import paramiko
import time

VPS_HOST = "91.108.107.50"
VPS_PORT = 65002
VPS_USER = "u881842192"
VPS_PASSWORD = "Imnotbadbtw@idunnowhatyouthink1"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(VPS_HOST, port=VPS_PORT, username=VPS_USER, password="Imnotbadbtw@idunnowhatyouthink1", timeout=30)

def run_cmd(cmd):
    stdin, stdout, stderr = ssh.exec_command(cmd)
    exit_status = stdout.channel.recv_exit_status()
    out = stdout.read().decode()
    err = stderr.read().decode()
    if out: print(f"OUT: {out}")
    if err: print(f"ERR: {err}")
    return exit_status

# Kill any existing server on port 80
run_cmd("pkill -f 'python.*otamzo_server' 2>/dev/null; sleep 1")

# Write the HTTP server script
server_code = '''#!/usr/bin/env python3
import http.server
import socketserver
import os

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
    with socketserver.TCPServer(("", 80), APKHandler) as httpd:
        print(f"Serving at port {PORT}")
        httpd.serve_forever()
'''

# Write server script
stdin, stdout, stderr = ssh.exec_command("cat > /home/u881842192/otamzo_server.py << 'PYEOF'\nimport http.server\nimport socketserver\nimport os\n\nclass APKHandler(http.server.SimpleHTTPRequestHandler):\n    def __init__(self, *args, **kwargs):\n        super().__init__(*args, directory=\"/home/u881842192/otamzo-download-page\", **kwargs)\n    \n    def end_headers(self):\n        self.send_header('Access-Control-Allow-Origin', '*')\n        super().end_headers()\n    \n    def guess_type(self, path):\n        if path.endswith('.apk'):\n            return 'application/vnd.android.package-archive'\n        return super().guess_type(path)\n\nif __name__ == \"__main__\":\n    PORT = 80\n    os.chdir(\"/home/u881842192/otamzo-download-page\")\n    with socketserver.TCPServer((\"\", 80), APKHandler) as httpd:\n        print(f\"Serving at port {PORT}\")\n        httpd.serve_forever()\nPYEOF")
print(stdout.read().decode())
print(stderr.read().decode())

# Kill any existing server
run_cmd("pkill -f otamzo_server 2>/dev/null; sleep 1")

# Start server in background
run_cmd("cd /home/u881842192/otamzo-download-page && nohup python3 /home/u881842192/otamzo_server.py > otamzo_server.log 2>&1 &")

time.sleep(2)

# Check if running
run_cmd("ps aux | grep otamzo_server")

# Check port 80
run_cmd("netstat -tlnp 2>/dev/null | grep :80 || ss -tlnp 2>/dev/null | grep :80")

# Test with curl
run_cmd("curl -s http://localhost:80/ | head -20")

ssh.close()
