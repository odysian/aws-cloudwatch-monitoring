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

## EC2 Launch Template Configuration
- Amazon Linux 2023 640bit
- t3.micro
- Security group: allowing SSH from my IP, and HTTP from anywhere (will change to ALB security group later)
    - Inbound: HTTP(Anywhere), SSH(My IP)
    - Outbound: All traffic
- EBS 8GB gp3 storage (encrypted)
- IAM role with attached permissions for CloudWatch agent and Systems Manager:
    - CloudWatchAgentServerPolicy
    - AmazonSSMManagedInstanceCore
- Tags:
    - Name: webapp-instance
    - Environment: dev
    - Project: cloudwatch-monitoring
- 
