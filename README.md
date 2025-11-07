# aws-cloudwatch-monitoring
CloudWatch monitoring solution for a 3-tier web application

**VPC Config**
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

**RDS Config**
- MySQL 8.0.42 
- db.t3.micro
- 20GB gp2
- Single AZ deployment
- Security Group: webapp-rds-sg
    - Inbound:  MYSQL/Aurora:3306(webapp-ec2-sg)

**EC2 Launch Template Config**
- AMI: Amazon Linux 2023 640bit
- Instance type: t3.micro
- Storage: EBS 8GB gp3 storage (encrypted)
- Security group: webapp-ec2-sg
    - Inbound: 
        - HTTP: webapp-alb-sg
        - SSH: My IP    
- Network interface auto-assigns IPv4 address
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

**Application Load Balancer Config**
- Name: webapp-alb
- Internet facing IPv4
- Subnets: 
    - us-east-1a: public-subnet1 (10.0.0.0/20)
    - us-east-1b: public-subnet2 (10.0.16.0/20)
- Security Group: webapp-alb-sg
    - Inbound: HTTP:80(Anywhere)
    - Outbound: All traffic
- Listener: HTTP:80 forwarding to webapp-tg
- DNS name: webapp-alb-1270271488.us-east-1.elb.amazonaws.com

**Target Group Config**
- Name: webapp-tg
- Protocol: HTTP(80) | Version: HTTP1
- Health check path: /index.php
- Healthy/Unhealthy Threshold: 2 checks
- Targets: Ec2 instances managed by ASG

**Auto Scaling Group Config**
- Name: webapp-asg
- Launch Template: webapp-lt (latest version)
- Subnets: Both public subnets
- Desidred: 2, Min: 2, Max: 4
- Health check type: ELB (not just EC2)
- Health check grace period: 300 seconds

**Security Architecture:**
- EC2 instances only allow HTTP traffic from ALB security group
- Instances no longer have direct internet access via their security group
- All traffic routes through ALB for load distribution

![Application Load Balancer Resource Map](screenshots/alb-resource-map.png)

**Testing**

```bash
# Verify load balancing
for i in {1..10}; do curl http://webapp-alb-xxx.elb.amazonaws.com; done

# Output shows requests distributed across instances
Status: OK
Server: ip-10-0-31-184.ec2.internal
Database: Connected
Time: 2025-11-07 02:21:50
Status: OK
Server: ip-10-0-31-184.ec2.internal
Database: Connected
Time: 2025-11-07 02:21:50
```


