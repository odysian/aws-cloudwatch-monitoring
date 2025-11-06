#!/bin/bash
# Update system
yum update -y

# Install Apache and PHP
yum install -y httpd php php-mysqli

# Start Apache
systemctl start httpd
systemctl enable httpd

# RDS connection info
RDS_ENDPOINT="database-cloudwatch-monitoring.c0fekuwkkx5w.us-east-1.rds.amazonaws.com"
DB_USER="admin"
DB_PASS="odysbase69"
DB_NAME="webapp"

# Wait for RDS to be reachable
echo "Waiting for RDS to be available..."
until mysql -h $RDS_ENDPOINT -u $DB_USER -p$DB_PASS -e "USE $DB_NAME;" 2>/dev/null; do
    echo "RDS not ready yet, sleeping 10s..."
    sleep 10
done
echo "RDS is reachable!"

# Create simple status page with DB connection
cat > /var/www/html/index.php << EOF
<?php
\$host = "$RDS_ENDPOINT";
\$user = "$DB_USER";
\$pass = "$DB_PASS";
\$db   = "$DB_NAME";

\$conn = new mysqli(\$host, \$user, \$pass, \$db);

if (\$conn->connect_error) {
    http_response_code(500);
    die("Database connection failed: " . \$conn->connect_error);
}

// Simple status endpoint
echo "Status: OK\n";
echo "Server: " . gethostname() . "\n";
echo "Database: Connected\n";
echo "Time: " . date('Y-m-d H:i:s') . "\n";

\$conn->close();
?>
EOF

# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

# Create CloudWatch agent config
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
  "metrics": {
    "append_dimensions": {
      "InstanceId": "${aws:InstanceId}"
    },
    "metrics_collected": {
      "cpu": {
        "measurement": ["cpu_usage_idle", "cpu_usage_iowait"],
        "metrics_collection_interval": 60
      },
      "mem": {
        "measurement": ["mem_used_percent"],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": ["used_percent"],
        "metrics_collection_interval": 60,
        "resources": ["*"]
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/httpd/access_log",
            "log_group_name": "/aws/ec2/webapp/access",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/httpd/error_log",
            "log_group_name": "/aws/ec2/webapp/error",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s
