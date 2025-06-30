# app.py
import requests, os, time, jdatetime, json, sqlite3
from flask import Flask, abort, Response

# ... (تمام کد قبلی از بخش تنظیمات تا انتهای تابع show_subscription_page بدون هیچ تغییری اینجا قرار می‌گیرد) ...
# ...
# فقط خطوط زیر از انتهای فایل حذف می‌شوند:
# if __name__ == '__main__':
#     app.run(host='0.0.0.0', port=LISTEN_PORT)
