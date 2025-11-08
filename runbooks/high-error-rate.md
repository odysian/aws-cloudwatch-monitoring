# Runbook: High 5XX Error Rate
This runbook describes how I troubleshoot spikes in HTTP 5XX errors detected by the ALB.  
It outlines how to confirm the cause through metrics, logs, and simple app-level tests to quickly isolate issues in the PHP code or database connectivity.

## Alert
**Alarm Name:** ALB-High-Error-Rate
Triggered when >= 10 HTTP 5XX errors occur within 5 minutes

## Investigation Steps

1. **Check ALB Metrics**  
   Look for spikes in `HTTPCode_Target_5XX_Count` and high response times.
2. **Check Target Group Health**  
   Confirm if any EC2 targets are marked unhealthy.
3. **Check Apache and PHP Logs**  
    ```bash
    sudo tail -50 /var/log/httpd/error_log
    sudo tail -50 /var/log/php-fpm/error.log
    ```
4. **Verify Database Connectivity**
If the application fails to reach RDS, errors will appear as 500 responses.
5. **Test Application Response**
    ```bash
    curl http://<ALB-DNS>
    ```

## Common Causes & Fixes

| Cause | How to Check | Fix |
| ------| -------------|-----|
| Database connection failed | Try `mysql -h <endpoint> -u admin -p` | Ensure RDS running, SGs allow 3306 |
| PHP misconfiguration | Check PHP-FPM log | Fix syntax or revert to working launch template |
| File permissions | `ls -la /var/www/html` | `sudo chown apache:apache /var/www/html/*.php` |

## Takeaway
Most 5XX errors in this setup come from failed RDS connections or Apache misconfigurations. Checking logs and verifying the target group health quickly identifies the cause.