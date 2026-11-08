import paramiko

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

print("=== Installing nginx as root ===")
# Try to run apt as root using su
run_cmd("apt-get update && apt-get install -y nginx")

print("=== Configuring nginx ===")
nginx_config = '''server {
    listen 80;
    server_name otamzo.com www.otamzo.com;
    root /home/u881842192/otamzo-download-page;
    index index.html index.htm;

    location / {
        autoindex on;
        autoindex_exact_size off;
        autoindex_localtime on;
    }

    location ~ \\.apk$ {
        add_header Content-Type application/vnd.android.package-archive;
        add_header Content-Disposition "attachment";
    }
}'''

# Write nginx config
stdin, stdout, stderr = ssh.exec_command("cat > /etc/nginx/sites-available/otamzo << 'EOF'\n" + nginx_config + "\nEOF")
print(stdout.read().decode())

# Enable site
run_cmd("ln -sf /etc/nginx/sites-available/otamzo /etc/nginx/sites-enabled/")
run_cmd("rm -f /etc/nginx/sites-enabled/default")

# Fix permissions
run_cmd("chmod 755 /home/u881842192/otamzo-download-page")
run_cmd("chmod 755 /home/u881842192/otamzo-download-page/*")
run_cmd("chmod 644 /home/u881842192/otamzo-download-page/*/*.apk")
run_cmd("chown -R u881842192:www-data /home/u881842192/otamzo-download-page")

# Test nginx config
run_cmd("nginx -t")

# Start/restart nginx
run_cmd("service nginx restart")
run_cmd("service nginx status")

print("\n=== Checking if files are accessible ===")
stdin, stdout, stderr = ssh.exec_command("ls -la /home/u881842192/otamzo-download-page/customer/")
print(stdout.read().decode())

ssh.close()
print("\n✅ nginx configured!")
