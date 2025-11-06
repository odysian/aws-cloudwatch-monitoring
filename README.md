# aws-cloudwatch-monitoring
CloudWatch monitoring solution for a 3-tier web application

## VPC Setup
**Configuration**: 
- VPC CIDR: 10.0.0.0/16
- Availability Zones: 2 (us-east-1a, us-east-1b)
- Public subnets: 10.0.0.0/20, 10.0.16.0/20
- Private subnets: 10.0.128.0/20, 10.0.144.0/20
- NAT Gateways: 0 (keeping costs down for learning project)
- 1 Internet Gateway attached to VPC
- 1 Public Route Table with IGW route (0.0.0.0/0 -> igw)
- 2 Private route tables (one per AZ)
- Public subnets associated with public route table
- Private subnets associated with respective private route table
![Resource Map](screenshots/vpc-resource-map.png)
- **Design Choice:** Used public subnets for all resources initially to avoid NAT Gateway costs. In production, EC2 and RDS would go in the private subnets with NAT for internet access. The current setup is secure enough for a monitoring project since RDS won't be public and EC2 security groups will be restrictive.

## RDS Configuration
- MySQL 8.0.42 
- db.t3.micro
- 20GB gp2
- Single AZ deployment
- Security Group only allows access from EC2 security group

## EC2 Launch Template Configuration
- Amazon Linux 2023 640bit
- t3.micro
- Security group: allowing SSH from my IP, and HTTP from anywhere (will change to ALB security group later)
    - Inbound: HTTP(Anywhere), SSH(My IP)
    - Outbound: All traffic
- Network interface that auto-assigns IPv4 address
- EBS 8GB gp3 storage (encrypted)
- IAM role with attached permissions for CloudWatch agent and Systems Manager:
    - CloudWatchAgentServerPolicy
    - AmazonSSMManagedInstanceCore
- [User Data:](scripts/user-data-full-config.sh)
    - Installs PHP, Apache and CloudWatch Agent
    - Connects to RDS
    - Configures CloudWatch agent
- Tags:
    - Name: webapp-instance
    - Environment: dev
    - Project: cloudwatch-monitoring

## CloudWatch Monitoring Setup

### Dashboard Configuration

**EC2 Metrics:**
- CPU Usage (Idle) - tracking CPU availability
- Memory Usage - percentage of RAM utilizied
- Root Disk Usage - filesystem capacity monitoring

**RDS Metrics:**
- CPU Utilization - database processing load
- Free storage space - available disk capacity
- Database connections - active connection count

![CloudWatch Dashboard](screenshots/cloudwatch-dashboard.png)

### Alarm Configuration and Testing

**Test Alarm Created:**
- Metric: Memory Usage (mem_used_percent)
- Threshold >= 50% for 1 datapoint within 1 minute
- Action: SNS topic (webapp-alerts) -> Email notification
- State: Configured and verified

**Testing Process:**
```bash
# Generated memory usage with stress-ng
stress-ng --vm 1 --vm-bytes 400M --timeout 120s
```

**Results:**
- Memory usage spiked to 68%
- Alarm triggered successfully 
- SNS Email notification received within 1-2 minutes
- Alarm state transitioned: OK -> In alarm -> OK

![Alarm Triggered](screenshots/alarm-triggered1.png)
![Alarm History](screenshots/alarm-history.png)
![Email Alert](screenshots/email-alert.png)

**Lessons Learned:**
- Cloudwatch agent metrics have ~1 minute collection interval
- Make sure dashboard widget collection period is set to 1min
- Email delivery is reliable and was able to have the notification pushed from gmail to my phone
