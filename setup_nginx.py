import paramiko

VPS_HOST = "91.108.107.50"
VPS_PORT = 65002
VPS_USER = "u881842192"
VPS_PASSWORD = "Imnotbadbtw@idunnowhatyouthink1"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(VPS_HOST, port=65002, username=VPS_USER, password="Imnotbadbtw@idunnowhatyouthink1", timeout=30)

def run_cmd(cmd, use_sudo=False):
    prefix = "sudo " if use_sudo else ""
    stdin, stdout, stderr = ssh.exec_command(f"{prefix}{cmd}")
    exit_status = stdout.channel.recv_exit_status()
    out = stdout.read().decode()
    err = stderr.read().decode()
    if out: print(f"OUT: {out}")
    if err: print(f"ERR: {err}")
    return exit_status

print("=== Installing nginx ===")
run_cmd("apt-get update", use_sudo=True)
run_cmd("apt-get install -y nginx", use_sudo=True)

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

    # Allow direct APK downloads
    location ~ \\.apk$ {
        add_header Content-Type application/vnd.android.package-archive;
        add_header Content-Disposition "attachment";
    }
}'''

# Write nginx config
stdin, stdout, stderr = ssh.exec_command("sudo tee /etc/nginx/sites-available/otamzo > /dev/null << 'EOF'\n" + nginx_config + "\nEOF")
print(stdout.read().decode())
print(stderr.read().decode())

# Enable site
run_cmd("ln -sf /etc/nginx/sites-available/otamzo /etc/nginx/sites-enabled/", use_sudo=True)
run_cmd("rm -f /etc/nginx/sites-enabled/default", use_sudo=True)

# Fix permissions
run_cmd("chmod 755 /home/u881842192/otamzo-download-page", use_sudo=True)
run_cmd("chmod 755 /home/u881842192/otamzo-download-page/*", use_sudo=True)
run_cmd("chmod 644 /home/u881842192/otamzo-download-page/*/*.apk", use_sudo=True)

# Fix group ownership for nginx
run_cmd("chown -R u881842192:www-data /home/u881842192/otamzo-download-page", use_sudo=True)

# Test nginx config
run_cmd("nginx -t", use_sudo=True)

# Restart nginx
run_cmd("systemctl restart nginx", use_sudo=True)
run_cmd("systemctl enable nginx", use_sudo=True)

# Check status
stdin, stdout, stderr = ssh.exec_command("systemctl status nginx --no-pager")
print(stdout.read().decode())
print(stderr.read().decode())

print("\n=== Checking if files are accessible ===")
stdin, stdout, stderr = ssh.exec_command("ls -la /home/u881842192/otamzo-download-page/customer/")
print(stdout.read().decode())

ssh.close()
print("\n✅ nginx configured for otamzo.com!")
