#!/bin/bash

AMI_ID="ami-09c813fb71547fc4f"
SG_ID="sg-06fe68e538f97e025"
INSTANCES=( "mongodb" "catalogue" "payment" "shipping" "frontend" "redis" "mysql" "rabbitmq" "user" "cart" "dispatch" )

ZONE_ID="Z0025773HL0IRVDCYXE5"
DOMAIN_NAME="daws86s.site"

for instance in "${INSTANCES[@]}"
do
    INSTANCE_ID=$(aws ec2 run-instances \
        --image-id "$AMI_ID" \
        --instance-type t2.micro \
        --security-group-ids "$SG_ID" \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance}]" \
        --query 'Instances[0].InstanceId' \
        --output text)

    echo "Launched instance $instance with ID $INSTANCE_ID"

    # Wait for the instance to be in 'running' state before fetching IP
    aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"

    if [ "$instance" != "frontend" ]; then
        IP=$(aws ec2 describe-instances \
            --instance-ids "$INSTANCE_ID" \
            --query 'Reservations[0].Instances[0].PrivateIpAddress' \
            --output text)
    else
        IP=$(aws ec2 describe-instances \
            --instance-ids "$INSTANCE_ID" \
            --query 'Reservations[0].Instances[0].PublicIpAddress' \
            --output text)
        echo "Instance $instance has public IP address $IP"
    fi

    echo "$instance -> $IP"
done
