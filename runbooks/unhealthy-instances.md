# Runbook: Unhealthy EC2 Instances
This runbook explains how I troubleshoot situations where one or more EC2 instances become **unhealthy** in the ALB target group.  
It walks through how to confirm the issue, check logs, and restore service within an Auto Scaling Group environment.

## Alert
**Alarm Name:** ASG-Single-Instance-Unhealthy  
Triggered when one or more instances in the Auto Scaling Group are marked **unhealthy** by the Application Load Balancer.

## Symptoms
- Target group shows one or more unhealthy targets  
- Application may load slowly or intermittently fail  
- Auto Scaling Group might begin replacing instances automatically  

## Investigation Steps

### 1. Check Target Group Health
```bash
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:us-east-1:631353662337:targetgroup/webapp-tg/088b3e5e616624da
```

### 2. Verify Instance Status
- Open the EC2 Console → Instances
- Confirm the instance is running and passing both Status Checks

### 3. Connect to the Instance
```bash
# Option 1: SSH
ssh -i webapp-key.pem ec2-user@<instance-ip>

# Option 2: Session Manager
aws ssm start-session --target i-<instance-id>
```
### 4. Check Web Server Health
```bash
# Verify Apache status
sudo systemctl status httpd

# Test health endpoint
curl localhost/healthcheck.php
```
### 5. Review Logs
```bash
# Apache logs
sudo tail -50 /var/log/httpd/error_log

# Cloud-init (user data) logs
sudo tail -50 /var/log/cloud-init-output.log
```

## Common Causes and Fixes

| Cause | How to Check | Fix |
|-------|--------------|-----|
| **Apache stopped or failed to start** | `systemctl status httpd` | Restart Apache:<br>`sudo systemctl start httpd && sudo systemctl enable httpd` |
| **Database connection failed** | `curl localhost/index.php` shows “Database connection failed” | - Ensure RDS is running<br>- Check RDS SG allows port 3306 from EC2 SG<br>- Verify credentials in `/var/www/html/index.php` |
| **User data failed during launch** | Missing `/var/www/html/index.php` or PHP not installed | Check `/var/log/cloud-init-output.log` for errors and fix the launch template |

## What I'd Try First
1. Restart Apache on the unhealthy instance
2. Test database connectivity manually
3. If the issue persists, terminate the instance and let ASG launch a new one
4. If replacement instance also fails, investigate launch template or user data script


## Prevention
- Keep health check grace period long enough (e.g., 300s) for user data to finish
- Use CloudWatch dashboards to spot recurring instance issues
- Aggregate Apache logs in CloudWatch for easier troubleshooting
- Use Session Manager instead of SSH for faster access

## Takeaway
An unhealthy instance usually means the web server or RDS connection failed during startup.
Restarting Apache or replacing the instance resolves most cases quickly. Consistent logging and properly tested launch templates prevent repeat issues.