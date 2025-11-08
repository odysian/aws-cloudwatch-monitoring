# Deployment Guide

## Overview
This document describes how to deploy and validate the AWS CloudWatch Monitoring environment.
It covers setup verification for EC2 instances, RDS connectivity, CloudWatch Agent configuration, and ALB/ASG integration.
> *Estimated setup time: ~25–30 minutes manually via AWS Console / CLI.*

## Key Configuration Details

### EC2

- AMI: Amazon Linux 2023 (x86_64)
- Instance type: t3.micro
- User Data installs Apache, PHP, and CloudWatch Agent
- Waits for RDS connectivity using `mariadb105`
- Publishes ASG-level metrics via `AutoScalingGroupName`
- Tags: `Name: webapp-asg-instance`,`Environment: dev`, `Project: cloudwatch-monitoring`

### RDS
- MySQL 8.0.42
- db.t3.micro, 20GB gp2
- Single-AZ deployment
- Security group allows port 3306 only from EC2 SG

### ALB & Target Group

- Internet-facing ALB on port 80
- Health check path: `/healthcheck.php` (lightweight, no DB dependency)
- Listener forwards traffic to `webapp-tg`
- 2 healthy targets managed by ASG

### Auto Scaling Group

- Desired: 2  Min: 2  Max: 4
- Health check type: ELB
- Grace period: 300 seconds

### Security Architecture 

- EC2 only allows HTTP from ALB SG
- No direct internet access
- All traffic flows through ALB

## Pre-Deployment Checks

### IAM Role
- EC2 instance profile includes:
  - CloudWatchAgentServerPolicy 
  - AmazonSSMManagedInstanceCore
- **Security Groups:**
  - EC2: 
    - Inbound: HTTP (80) from `webapp-alb-sg` only
    - SSH (22) from your IP
  - RDS: 
    - MySQL/Aurora (3306) from `webapp-ec2-sg` only
  - ALB: 
    - HTTP (80) from anywhere (0.0.0.0/0)

### RDS 
- MySQL instance in **available** state 
- Note endpoint & admin credentials

### Launch Template
- Uses latest version with correct **user data**, including:
  - Apache, PHP, and CloudWatch Agent installation 
  - `mariadb105` for RDS connectivity checks
  - `/healthcheck.php` endpoint creation
  - File permissions and ownership for Apache
  - ASG dimension added to CloudWatch metrics

### Target Group
- Protocol HTTP 80 
- Health check: `/healthcheck.php`
- Healthy/Unhealthy threshold: 2 
- Timeout: 5s, Interval: 30s, 
- Success codes: 200

### Load Balancer
- DNS: `webapp-alb-1270271488.us-east-1.elb.amazonaws.com`

## Quick Reference / Checklist

### Auto Scaling & EC2
- [ ] Launch template updated to latest version
- [ ] ASG desired/running: **2/2**
- [ ] Health check grace period: **300s**
- [ ] EC2 SG inbound from ALB only

### Testing
- [ ] `curl http://<ALB-DNS>` returns status page
- [ ] `systemctl status httpd` → active
- [ ] CloudWatch Agent running & configured
- [ ] RDS connectivity verified
```bash
mysql -h <RDS-endpoint> -u admin -p
SHOW DATABASES;
```

### Monitoring Verification
- [ ] Dashboard shows ASG-level CPU & network
- [ ] Memory & Disk aggregated via CloudWatch Agent
- [ ] ALB metrics visible (requests, latency, 4XX/5XX errors)
- [ ] SNS notifications received during alarm test

## Post-Deployment Validation

### Refresh ASG Instances
```bash 
aws autoscaling start-instance-refresh \
--auto-scaling-group-name webapp-asg \
--preferences '{"MinHealthyPercentage":100}`
```

### EC2 Web Server Test
```bash
curl http://<ALB-DNS>
# Expected:
# Status: OK
# Server: ip-10-0-xx-xx.ec2.internal
# Database: Connected
# Time: 2025-11-07 02:21:50

# Verify Load Balancing
for i in {1..10}; do curl webapp-alb-1270271488.us-east-1.elb.amazonaws.com; done
# Expected output distributed across instances
# Status: OK
# Server: ip-10-0-31-184.ec2.internal
# Database: Connected
# Time: 2025-11-07 02:21:50
```

### Check services and logs
```bash
systemctl status httpd
sudo tail -50 /var/log/httpd/error_log
sudo tail -50 /var/log/cloud-init-output.log
```

### CloudWatch Agent

```sh

rpm -qa | grep amazon-cloudwatch-agent
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a status
sudo tail -50 /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log
# Expected:
# Status: running
# Config status: configured
# Metrics visible:
#  -cpu_usage_idle
#  -mem_used_percent
#  -disk_used_percent
```

### RDS

```bash
mysql -h <RDS endpoint> -u admin -p
SHOW DATABASES;
```

## Troubleshooting

> **ASG Instance Refresh Delays**
> When performing an instance refresh, Auto Scaling replaces instances gradually to maintain the configured minimum healthy percentage.
> Each instance waits for health checks to pass before the next one is replaced.
> If your health check grace period is 300s (5 minutes), a full refresh for two instances may take 10–15 minutes.
> For a faster refresh with a brief downtime, you can manually terminate both instances. The ASG will immediately launch replacements.

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| Target Unhealthy | Apache not running / healthcheck failed | Restart httpd, check `healthcheck.php` |
| DB connection error | RDS not reachable | Verify RDS SG allows 3306 from EC2 SG | 
| PHP page missing | User data failed | Inspect `/var/log/cloud-init-output.log` |
| Metrics missing | Agent misconfigured | Re-run CloudWatch Agent control command |
| Alarm not triggering | Wrong metric / namespace | Verify alarm uses ASG-level metrics|



## Notes
- Always verify RDS and EC2 SG pairing before launch
- Health check grace period prevents false negatives during boot
- Use **Session Manager** instead of SSH for simpler access
- Save time by testing user data on a single instance before updating ASG