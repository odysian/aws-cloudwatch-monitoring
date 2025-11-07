# Deployment

## Overview
This document outlines the deploment validation steps for the aws-cloudwatch-monitoring project. Verifying EC2 setup, Apache/PHP config, RDS connectivity and CloudWatch Agent functionality.

## Pre-Deployment Checks

**IAM Role:** 
- Instance profile attached to EC2 with `CloudWatchAgentServerPolicy` and `AmazonSSMManagedInstanceCore`

**Security Groups:**
- EC2-Test SG: 
    - Inbound: HTTP (80) from 0.0.0.0/0, SSH (22) from your IP.
    - Outbound: All traffic.
- RDS SG:
    - Inbound: MySQL/Aurora (3306) only from EC2 SG.
- ALB SG:
    - Inbound: HTTP (80) from 0.0.0.0/0

**RDS Database:**
- MySQL instance created and in **available** state
- Note endpoint and admin credentials

**Launch Template:**
- Configured with latest user data
    - Apache
    - PHP
    - CloudWatch Agent

**Target Group**
- Protocol: HTTP(80)
- Health Checks:
    - Protocol: HTTP
    - Path: /index.php
    - Healthy Threshold: 2 consecutive checks
    - Unhealthy Threshold: 2 consecutive checks
    - Timeout: 5 seconds
    - Interval 30 seconds
    - Success Codes: 200

**Application Load Balancer**
- 
- webapp-alb-1270271488.us-east-1.elb.amazonaws.com


## Testing and Verification

### EC2 Test Instance
```sh
# Confirm web server is responding
curl http://<public ip>

# Expected output:
# Status: OK
# Server: ip-10-0-15-94.ec2.internal
# Database: Connected
# Time: 2025-11-06 19:02:57

# Check Apache server status
systemctl status httpd

#View Apache error log
sudo tail -50 /var/log/httpd/error_log
```
**Expected Results**
- `curl` returns status page with "Status:OK"
- `httpd` service is active (running)
- No major errors in `/var/log/httpd/error_log`


### CloudWatch Agent

```sh
# Check if CloudWatch agent is installed
`rpm -qa | grep amazon-cloudwatch-agent`

# Check CloudWatch agent status
`sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a status`

# View CloudWatch agent logs
`sudo tail -50 /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log` -> Logs
```
**Expected results**
- `status`: "running"
- `configstatus`: "configured"
- Metrics visible in CloudWatch -> Metrics -> CWAgent
    - `cpu_usage_idle`
    - `cpu_usage_iowait`
    - `mem_used_percent`
    - `disk_used_percent`

### RDS Connection

```sh
# Install MySQL client for Amazon Linux 2023 (MariaDB) 
sudo dnf install -y mariadb105

# Test RDS connection
mysql -h database-cloudwatch-monitoring.c0fekuwkkx5w.us-east-1.rds.amazonaws.com -u admin -p
```
**Expected Results**
- Connection succeeds
- `SHOW DATABASES;` displays system databases
**Quick fixes if failing**
- Verify RDS SG allows inbound 3306 from EC2 SG
- Ensure RDS instance is in "available" state
- Double check RDS endpoint, username, and password

## Troubleshooting

### Issue: Instances Unhealthy in Target Group

**Symptoms:**
- Target group shows unhealthy status
- Health check returns "Connection refused" or timeout
- `curl localhost/index.php` returns "file not found"

**Root Cause:**
User data script waiting for RDS connectivity but timing out before creating application files.

**Solution:**
```bash
# Check user data execution
sudo cat /var/log/cloud-init-output.log | tail -100

# Verify Apache is running
sudo systemctl status httpd

#Test health check endpoint
curl localhost/index.php

# If file missing, user data failed - check logs for where it stopped
# Install mariadb105 in user data to enable RDS connectivity checks
```

**Prevention:**
- Ensure RDS security group allows EC2 security group before launching ASG
- Include mariadb105 package in user data for RDS verification
- Set health check grace period to 300s to allow full startup time

