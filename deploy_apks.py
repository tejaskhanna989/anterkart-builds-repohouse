import paramiko
import os
import sys

VPS_HOST = "91.108.107.50"
VPS_PORT = 65002
VPS_USER = "u881842192"
VPS_PASSWORD = "Imnotbadbtw@idunnowhatyouthink1"
DEPLOY_BASE = "/home/u881842192/otamzo-download-page"

APPS = ["customer", "vendor", "rider"]
ARTIFACTS_BASE = "/home/tejas/Projects/DKP/AnterKart/AnterKart-SaaS/food-multi-copy/flutter/artifacts"

def deploy():
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        print(f"Connecting to {VPS_HOST}:{VPS_PORT}...")
        ssh.connect(VPS_HOST, port=VPS_PORT, username=VPS_USER, password="Imnotbadbtw@idunnowhatyouthink1", timeout=30)
        print("Connected successfully!")
        
        # Create directories via SSH command (supports recursive)
        stdin, stdout, stderr = ssh.exec_command(f"mkdir -p /home/u881842192/otamzo-download-page/{{customer,vendor,rider}}")
        exit_status = stdout.channel.recv_exit_status()
        if exit_status != 0:
            print(f"Warning: mkdir stderr: {stderr.read().decode()}")
        else:
            print("Remote directories created successfully")
        
        sftp = ssh.open_sftp()
        
        # Upload APKs
        for app in ["customer", "vendor", "rider"]:
            local_dir = os.path.join("/home/tejas/Projects/DKP/AnterKart/AnterKart-SaaS/food-multi-copy/flutter/artifacts", app)
            remote_dir = f"/home/u881842192/otamzo-download-page/{app}"
            
            print(f"\nUploading {app} APKs...")
            for filename in sorted(os.listdir(local_dir)):
                if filename.endswith(".apk"):
                    local_path = os.path.join(local_dir, filename)
                    remote_path = f"/home/u881842192/otamzo-download-page/{app}/{filename}"
                    print(f"  Uploading {filename}...")
                    sftp.put(local_path, remote_path)
                    print(f"  ✓ {filename} uploaded")
        
        sftp.close()
        ssh.close()
        print("\n✅ All APKs deployed successfully to otamzo VPS!")
        
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    deploy()
