# Runbook: High 5XX Error Rate

## Alert
**Alarm Name:** PROD-P2-High-Error-Rate

- >= 10 HTTP 5XX errors in 5 minutes

## Investigation Steps

### 1. Check ALB Metrics
```
CloudWatch -> Metrics -> ApplicationELB
Look at:
- HTTPCode_Target_5XX_Count (spike?)
- TargetResponseTime (increased latency?)
- RequestCount (traffic spike causing issues?)
```

### 2. Check Target Health
```
EC2 Console -> Target Groups -> webapp-tg
Are all targets healthy?
```

### 3. Check Application Logs
```bash
# SSH/SSM to an instance
ssh -i webapp-key.pem ec2-user@<instance-ip>
aws ssm start-session --target i-<your-instance-id>

# Check Apache error log
sudo tail -100 /var/log/httpd/error_log

# Look for:
# - PHP errors
# - Database connection failures
# - File permission issues
```

### 4. Check CloudWatch Logs
```
CloudWatch -> Log Groups -> /aws/ec2/webapp/error
Filter: last 15 minutes
Look for patterns in errors
```

### 5. Test Manually
```bash
# From your machine
curl -v http://webapp-alb-1270271488.us-east-1.elb.amazonaws.com

# Or from instance
curl -v localhost/index.php
```

## Issues

### Issue 1: Database Connection Failed
- All requests returned 500

**Check:**
- RDS status (running vs stopped)
- RDS security group (allows 3306 from EC2)
- RDS CPU/connections (resource exhaustion?)

### Issue 2: PHP Configuration Error
- PHP errors in logs after recent changes

**Check:**
```bash
# Check PHP error log
sudo tail -50 /var/log/php-fpm/error.log

# Test PHP syntax
php -l /var/www/html/index.php
```

**Fix:**
- Rollback to last working launch template
- Correct syntax/credential errors in index.php

### Issue 3: File Permissions
**Check:**
```bash
ls -la /var/www/html/index.php
# Should be readable by apache user
```

**Fix:**
```bash
sudo chmod 644 /var/www/html/index.php
sudo chown apache:apache /var/www/html/index.php
```

## What I'd Try First
1. Increase ASG desired capacity temporarily
2. Revert to last known good launch template version
3. Consider rate limiting at ALB if traffic spike

## Next Steps
- Review logs to understand root cause
- Could improve code to handle errors better