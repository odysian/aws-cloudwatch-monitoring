# Runbook: RDS High CPU
This runbook explains how I investigate and resolve situations where the RDS database shows unusually high CPU usage.  
It focuses on using CloudWatch metrics and database inspection to identify inefficient queries, excessive connections, or instance size limitations.

## Alert
**Alarm Name:** RDS-High-CPU  
Triggered when database CPU utilization exceeds **90%** for two consecutive 5-minute periods.

## Symptoms
- Application responses are slow or timing out  
- CloudWatch dashboard shows CPUUtilization spikes  
- Increased 500-series errors from web servers  
- Possible rise in active connections or I/O activity

## Investigation Steps

### 1. Review CloudWatch Metrics
Check the following metrics for your RDS instance:
- **CPUUtilization** – overall database load  
- **DatabaseConnections** – active connection count  
- **ReadIOPS / WriteIOPS** – I/O demand  
- **FreeStorageSpace** – ensure sufficient storage  

> CloudWatch Console → RDS → Metrics → `DBInstanceIdentifier`

### 2. Connect to the Database
```bash
mysql -h <rds-endpoint> -u admin -p
# Check for queries that have been running for a long time
SHOW FULL PROCESSLIST;
```

| Cause | How to Check | Fix |
| ------|--------------|-----|
| Too many open connections | Compare `DatabaseConnections` to baseline | Use connection pooling or increase max connections |
| Inefficient queries | Use `EXPLAIN` in MySQL to analyze query plans | Add missing indexes or optimize queries |
| Instance size too small | Review CPU pattern over time | Scale up to next instance class temporarily |
| Traffic spike | Compare RequestCount from ALB metrics | Monitor if usage stabilizes; consider autoscaling RDS if persistent |

## Immediate Actions

1. Check if the spike is short-lived or persistent.
2. Identify and kill any stuck or heavy queries:
```sql
SHOW FULL PROCESSLIST;
KILL <process_id>;
```
3. Restart application layer if too many idle connections accumulate.
4. If load persists, scale RDS instance vertically (larger class).

## Preventive Measures

- Add indexes for frequent read queries
- Avoid SELECT * in production queries
- Enable Performance Insights in RDS for deeper analysis
- Implement query caching or a read replica for high read traffic
- Monitor connection usage trends via CloudWatch dashboards

## Takeaway

High RDS CPU usage usually comes from inefficient queries or too many simultaneous connections.
Monitoring query performance and scaling appropriately keeps database responsiveness stable and prevents app-level slowdowns.