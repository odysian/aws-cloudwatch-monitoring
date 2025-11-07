# Runbook: Unhealthy EC2 Instances

## Alert
**Alarm Name:** PROD-P2-Single-Instance-Unhealthy

- Target group shows 1+ unhealthy targets
- Reduced application capacity

## Investigation Steps

### 1. Check Target Group Health
```bash
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:us-east-1:631353662337:targetgroup/webapp-tg/088b3e5e616624da
```

### 2. Check Instance status in Console
- Verify instance is running and check status checks

### 3. SSH/SSM to Instance
```bash
ssh -i webapp-key.pem ec2-user@<instance-ip>
aws ssm start-session --target i-<your-instance-id>

# Check Apache status
sudo systemctl status httpd

# Test health endpoint
curl localhost/healthcheck.php

# Check logs
sudo tail -50 /var/log/httpd/error_log
sudo tail -50 /var/log/cloud-init-output.log
```

## Issues

### Issue 1: Apache not running
**Steps:**
```bash
sudo systemctl start httpd
sudo systemctl enable httpd

# Wait a couple minutes for health checks to pass
```

### Issue 2: Can't Connect to RDS
`curl localhost/index.php` returns "Database connection failed"

**Check:**
```bash
# Check RDS connection from instance
mysql -h database-cloudwatch-monitoring.c0fekuwkkx5w.us-east-1.rds.amazonaws.com -u admin -p
```

**Fix:**
- Verify RDS is running
- Check RDS security group allows port 3306 from EC2 SG
- Verify endpoint/password in /var/www/html/index.php

### Issue 3: User data didn't fully execute
PHP file doesn't exist or Apache wasn't running

**Check:**
```bash
ls -la /var/www/html/index.php
# Check if file exists

sudo cat /var/log/cloud-init-output.log | tail -100
# Investigate logs
```

## What I'd Try First
1. SSH to instance and restart Apache
2. Test database connection
3. If neither works, terminate instance and let ASG replace it
4. Monitor new instance to see if problem repeats
5. If new instance also fails, the problem is in my launch template or infrastructure


## Prevention
- Detailed CloudWatch monitoring to see issues faster
- Aggregating logs to make troubleshooting easier
- Look into lambda auto-remediation

## Prevention Ideas
- Set up CloudWatch Logs for Apache errors
- Use Session Manager for easier access (no SSH key needed)
- Test launch template before updating ASG
- Keep ALB health check settings reasonable

## What I Learned
- Giving instances enough time for health checks matters
- CloudWatch agent logs can be helpful along with apache logs
- Make sure launch template works before updating ASG
- Restarting/replacing instance can be faster than troubleshooting