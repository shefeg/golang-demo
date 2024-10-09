#!/bin/bash

# Update the system and install necessary packages
dnf update -y
dnf install -y nginx golang git

# Start and enable Nginx
systemctl start nginx
systemctl enable nginx

# Clone the repository and set permissions
git clone https://github.com/YaroslavKSE/golang-demo-fork.git /home/ec2-user/golang-demo
chown -R ec2-user:ec2-user /home/ec2-user/golang-demo

# Set up Go environment for ec2-user
echo 'export PATH=$PATH:/usr/local/go/bin' >> /home/ec2-user/.bash_profile
echo 'export GOPATH=/home/ec2-user/go' >> /home/ec2-user/.bash_profile
echo 'export PATH=$PATH:$GOPATH/bin' >> /home/ec2-user/.bash_profile

# Build and run the Go application as ec2-user
sudo -u ec2-user bash << EOF
source /home/ec2-user/.bash_profile
cd /home/ec2-user/golang-demo
go build -o golang-demo
chmod +x golang-demo
EOF

# Create a systemd service for the Go application
cat <<EOT > /etc/systemd/system/golang-demo.service
[Unit]
Description=Golang Demo Application
After=network.target

[Service]
Environment="DB_ENDPOINT=${db_endpoint}"
Environment="DB_PORT=${db_port}"
Environment="DB_USER=${db_username}"
Environment="DB_PASS=${db_password}"
Environment="DB_NAME=${db_name}"
Environment="GOPATH=/home/ec2-user/go"
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/usr/local/go/bin:/home/ec2-user/go/bin"
ExecStart=/home/ec2-user/golang-demo/golang-demo
WorkingDirectory=/home/ec2-user/golang-demo
User=ec2-user
Restart=always

[Install]
WantedBy=multi-user.target
EOT

# Reload systemd, start and enable the golang-demo service
systemctl daemon-reload
systemctl start golang-demo
systemctl enable golang-demo

# Configure Nginx as a reverse proxy
cat <<EOT > /etc/nginx/conf.d/golang-demo.conf
server {
    listen 80;
    server_name _;
    location / {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOT

# Remove the default Nginx configuration
rm -f /etc/nginx/conf.d/default.conf

# Restart Nginx to apply changes
systemctl restart nginx