# Shut down for the night

# Set ASG desired capacity to 0
aws autoscaling update-auto-scaling-group \
    --auto-scaling-group-name webapp-asg \
    --min-size 0 \
    --desired-capacity 0

# Stop the RDS instance
aws rds stop-db-instance \
    --db-instance-identifier database-cloudwatch-monitoring

# Start up in the morning
aws autoscaling update-auto-scaling-group \
    --auto-scaling-group-name webapp-asg \
    --min-size 2 \
    --desired-capacity 2

aws rds start-db-instance \
    --db-instance-identifier database-cloudwatch-monitoring   
