# app.py
import requests
import json
import sqlite3
import time
from flask import Flask, abort, Response

# ================== تنظیمات اصلی (این بخش را با دقت ویرایش کنید) ==================
# 1. مسیر فایل دیتابیس پنل x-ui
DB_PATH = '/etc/x-ui/x-ui.db'

# 2. آدرس دامنه یا IP سرور
SERVER_IP = 'swe.nagarin.ir' 

# 3. پورت و مسیر ثابت برای لینک‌های اشتراک (بر اساس نمونه شما)
SUBSCRIPTION_PORT = 2083
SUBSCRIPTION_PATH = '/subscriptionlink/'
# =================================================================================

CACHE_DURATION_SECONDS = 300 
app = Flask(__name__)

# --- متغیرهای گلوبال برای سیستم کش ---
cached_content = {}
cache_timestamp = {}

def get_db_connection():
    try:
        conn = sqlite3.connect(f'file:{DB_PATH}?mode=ro', uri=True)
        conn.row_factory = sqlite3.Row
        return conn
    except sqlite3.Error as e:
        print(f"Database connection error: {e}")
        return None

def check_if_subid_exists_and_enabled(sub_id):
    """بررسی می‌کند که آیا sub_id در دیتابیس وجود دارد و فعال است یا خیر"""
    conn = get_db_connection()
    if not conn: return False
    inbounds = conn.execute('SELECT settings FROM inbounds WHERE enable = 1').fetchall()
    conn.close()
    for inbound in inbounds:
        try:
            settings = json.loads(inbound['settings'])
            for client in settings.get('clients', []):
                if client.get('subId') == sub_id and client.get('enable', False) is True:
                    return True
        except (json.JSONDecodeError, KeyError):
            continue
    return False

def get_raw_subscription_content(url):
    """محتوای متنی خام لینک اشتراک را با قابلیت کش برمی‌گرداند"""
    global cached_content, cache_timestamp
    current_time = time.time()
    
    if url in cached_content and (current_time - cache_timestamp.get(url, 0) < CACHE_DURATION_SECONDS):
        print(f">>> Using cached raw content for {url}")
        return cached_content[url]

    print(f">>> Fetching new raw content from {url}...")
    try:
        response = requests.get(url, timeout=10, verify=False)
        response.raise_for_status()
        
        raw_text = response.text
        # آپدیت کردن کش
        cached_content[url] = raw_text
        cache_timestamp[url] = current_time
        return raw_text
        
    except requests.exceptions.RequestException as e:
        print(f"ERROR fetching {url}: {e}")
        # در صورت خطا، اگر کش قدیمی وجود دارد، آن را برگردان
        if url in cached_content:
            return cached_content[url]
        return None

@app.route('/subscriptionlink/<sub_id>')
def proxy_subscription_page(sub_id):
    # 1. بررسی وجود و فعال بودن sub_id
    if not check_if_subid_exists_and_enabled(sub_id):
        abort(404)
    
    # 2. ساختن لینک سابسکریپشن اصلی
    source_url = f"https://{SERVER_IP}:{SUBSCRIPTION_PORT}/{SUBSCRIPTION_PATH.strip('/')}/{sub_id}"
    
    # 3. گرفتن محتوای خام از لینک
    raw_content = get_raw_subscription_content(source_url)
    
    if raw_content is None:
        abort(500, "Could not fetch subscription content from the source server.")
    
    # 4. برگرداندن محتوای خام با فرمت صحیح (text/plain)
    return Response(raw_content, mimetype='text/plain; charset=utf-8')

# خطوط زیر برای اجرای حرفه‌ای حذف می‌شوند. Gunicorn جایگزین آن است.
# if __name__ == '__main__':
#     app.run(host='0.0.0.0', port=LISTEN_PORT)
