#!/bin/bash

# Update the system
yum update -y

# Configure ECS agent
echo ECS_CLUSTER=${cluster_name} >> /etc/ecs/ecs.config
echo ECS_ENABLE_CONTAINER_METADATA=true >> /etc/ecs/ecs.config

# Install CloudWatch agent for better monitoring (optional)
yum install -y amazon-cloudwatch-agent

# Configure Docker for better memory management
cat > /etc/docker/daemon.json << EOF
{
  "log-driver": "awslogs",
  "log-opts": {
    "awslogs-group": "/ecs/${cluster_name}",
    "awslogs-region": "us-west-2"
  },
  "storage-driver": "overlay2",
  "max-concurrent-downloads": 3,
  "max-concurrent-uploads": 3,
  "default-runtime": "runc"
}
EOF

# Restart Docker service
systemctl restart docker

# Start ECS agent
systemctl enable ecs
systemctl start ecs

# Configure log rotation to save disk space (Free Tier optimization)
cat > /etc/logrotate.d/docker-containers << EOF
/var/lib/docker/containers/*/*.log {
  daily
  rotate 3
  missingok
  notifempty
  sharedscripts
  copytruncate
  compress
  maxsize 10M
}
EOF

# Clean up old log files to save space
find /var/lib/docker/containers -name "*.log" -type f -size +50M -delete

# Set up basic security updates
echo "0 2 * * * root yum update -y --security" | crontab -

# Install SSM agent for remote management (already included in Amazon Linux 2)
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent 