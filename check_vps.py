import paramiko

VPS_HOST = "91.108.107.50"
VPS_PORT = 65002
VPS_USER = "u881842192"
VPS_PASSWORD = "Imnotbadbtw@idunnowhatyouthink1"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(VPS_HOST, port=VPS_PORT, username=VPS_USER, password="Imnotbadbtw@idunnowhatyouthink1", timeout=30)

# Check current structure
stdin, stdout, stderr = ssh.exec_command("ls -la /home/u881842192/otamzo-download-page/")
print("=== /home/u881842192/otamzo-download-page/ ===")
print(stdout.read().decode())

# Check web server
stdin, stdout, stderr = ssh.exec_command("which nginx && nginx -v || which apache2 && apache2 -v || which httpd && httpd -v")
print("=== Web server ===")
print(stdout.read().decode())

# Check nginx config
stdin, stdout, stderr = ssh.exec_command("ls -la /etc/nginx/sites-enabled/ 2>/dev/null || ls -la /etc/apache2/sites-enabled/ 2>/dev/null")
print("=== Sites enabled ===")
print(stdout.read().decode())

# Check web root
stdin, stdout, stderr = ssh.exec_command("ls -la /var/www/ 2>/dev/null; ls -la /var/www/html/ 2>/dev/null")
print("=== /var/www/ ===")
print(stdout.read().decode())

ssh.close()
