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

# Check OS
run_cmd("cat /etc/os-release")
run_cmd("which apt || which yum || which dnf || which apk || which pacman")
run_cmd("which nginx || which apache2 || which httpd || which lighttpd")
run_cmd("ps aux | grep -E 'nginx|apache|httpd'")
run_cmd("netstat -tlnp 2>/dev/null | grep :80 || ss -tlnp 2>/dev/null | grep :80")

ssh.close()
