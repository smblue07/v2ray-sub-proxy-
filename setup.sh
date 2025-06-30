#!/bin/bash
set -e
echo "================================================="
echo "راه‌اندازی سرویس پراکسی اشتراک (نسخه HTTP)"
echo "================================================="

read -p "لطفا دامنه یا IP سرور خود را وارد کنید (مثال: sub.domain.com یا 1.2.3.4): " DOMAIN_OR_IP
read -p "لطفا پورتی که اپلیکیشن روی آن اجرا شود را وارد کنید (مثال: 5002): " APP_PORT

echo ">>> آپدیت سیستم و نصب پیش‌نیازها..."
sudo apt-get update
sudo apt-get install -y nginx python3-pip python3-venv

echo ">>> نصب پکیج‌های پایتون..."
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
deactivate

echo ">>> ساخت سرویس systemd برای اجرای دائمی برنامه..."
GUNICORN_PATH=$(pwd)/venv/bin/gunicorn
PROJECT_PATH=$(pwd)
APP_MODULE="app:app"

sudo tee /etc/systemd/system/subproxy.service > /dev/null <<EOF
[Unit]
Description=Gunicorn instance for V2Ray subscription proxy
After=network.target
[Service]
User=root
WorkingDirectory=$PROJECT_PATH
ExecStart=$GUNICORN_PATH --workers 3 --bind 127.0.0.1:$APP_PORT $APP_MODULE
Restart=always
[Install]
WantedBy=multi-user.target
EOF

echo ">>> کانفیگ Nginx به عنوان Reverse Proxy..."
sudo tee /etc/nginx/sites-available/subproxy_site > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN_OR_IP;

    location / {
        proxy_pass http://127.0.0.1:$APP_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF

sudo ln -s -f /etc/nginx/sites-available/subproxy_site /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx

echo ">>> فعال‌سازی و اجرای نهایی سرویس..."
sudo systemctl daemon-reload
sudo systemctl start subproxy
sudo systemctl enable subproxy

echo "================================================="
echo "🎉 نصب با موفقیت انجام شد! 🎉"
echo "سرویس شما اکنون روی آدرس زیر در دسترس است:"
echo "http://$DOMAIN_OR_IP/subscriptionlink/your_sub_id"
echo "================================================="
