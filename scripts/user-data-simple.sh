#!/bin/bash
yum update -y
yum install -y httpd
echo "Hello from $(hostname)" > /var/www/html/index.html
systemctl start httpd
systemctl enable httpd

# =========================================

#!/bin/bash
yum install -y python3 python3-pip
pip3 install pymysql flask

cat > /home/ec2-user/app.py << 'EOF'
from flask import Flask
import pymysql
app = Flask(__name__)

@app.route('/')
def status():
    try:
        conn = pymysql.connect(host='<RDS-ENDPOINT>', user='admin', password='odysbase69', db='webapp', connect_timeout=5)
        conn.close()
        return "Status: OK\nDatabase: Connected"
    except Exception as e:
        return f"Status: OK\nDatabase: Connection failed: {e}"

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
EOF

nohup python3 /home/ec2-user/app.py &



