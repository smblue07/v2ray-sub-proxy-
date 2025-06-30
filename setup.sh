#!/bin/bash

# توقف اسکریپت در صورت بروز هرگونه خطا
set -e

echo "================================================="
echo "راه‌اندازی سرویس پراکسی اشتراک V2Ray"
echo "================================================="

# دریافت اطلاعات از کاربر
read -p "لطفا ساب‌دامنه مورد نظر خود را وارد کنید (مثال: sub.mydomain.com): " SUBDOMAIN
read -p "لطفا یک ایمیل معتبر برای گواهی SSL وارد کنید: " EMAIL
read -p "لطفا پورتی که اپلیکیشن روی آن اجرا شود را وارد کنید (مثال: 5002): " APP_PORT

# آپدیت سیستم و نصب پیش‌نیازها
echo ">>> آپدیت سیستم و نصب پیش‌نیازها (nginx, python, pip, venv, certbot)..."
sudo apt-get update
sudo apt-get install -y nginx python3-pip python3-venv certbot python3-certbot-nginx

# نصب پکیج‌های پایتون
echo ">>> نصب پکیج‌های پایتون از requirements.txt..."
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
deactivate

# ساخت سرویس Gunicorn با systemd
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
Group=www-data
WorkingDirectory=$PROJECT_PATH
ExecStart=$GUNICORN_PATH --workers 3 --bind 127.0.0.1:$APP_PORT $APP_MODULE
Restart=always
StandardOutput=append:/var/log/subproxy.log
StandardError=append:/var/log/subproxy.log

[Install]
WantedBy=multi-user.target
EOF

# کانفیگ Nginx
echo ">>> کانفیگ Nginx به عنوان Reverse Proxy..."
sudo tee /etc/nginx/sites-available/$SUBDOMAIN > /dev/null <<EOF
server {
    listen 80;
    server_name $SUBDOMAIN;

    location / {
        proxy_pass http://127.0.0.1:$APP_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# فعال‌سازی سایت در Nginx
sudo ln -s -f /etc/nginx/sites-available/$SUBDOMAIN /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t

# *** تغییراصلی اینجاست ***
echo ">>> ری‌استارت کردن Nginx برای اعمال تنظیمات..."
sudo systemctl restart nginx

# دریافت گواهی SSL با Certbot
echo ">>> دریافت گواهی SSL برای $SUBDOMAIN..."
sudo certbot --nginx -d $SUBDOMAIN --non-interactive --agree-tos -m $EMAIL --redirect

# فعال‌سازی و اجرای نهایی سرویس‌ها
echo ">>> فعال‌سازی و اجرای نهایی سرویس..."
sudo systemctl daemon-reload
sudo systemctl start subproxy
sudo systemctl enable subproxy

echo "================================================="
echo "🎉 نصب با موفقیت انجام شد! 🎉"
echo "سرویس شما اکنون روی آدرس زیر در دسترس است:"
echo "https://$SUBDOMAIN"
echo "برای مشاهده لاگ‌های برنامه، از دستور زیر استفاده کنید:"
echo "sudo journalctl -u subproxy -f"
echo "================================================="
