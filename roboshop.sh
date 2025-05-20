#!/bin/bash

AMI_ID="ami-09c813fb71547fc4f"
SG_ID="sg-06fe68e538f97e025"
INSTANCES=( "mongodb" "catalogue" "payment" "shipping" "frontend" "redis" "mysql" "rabbitmq" "user" "cart" "dispatch" )

ZONE_ID="Z0025773HL0IRVDCYXE5"
DOMAIN_NAME="daws86s.site"

for instance in "${INSTANCES[@]}"
do
    echo "Launching instance: $instance"

    INSTANCE_ID=$(aws ec2 run-instances \
        --image-id "$AMI_ID" \
        --instance-type t3.micro \
        --security-group-ids "$SG_ID" \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance}]" \
        --query 'Instances[0].InstanceId' \
        --output text)

    if [ -z "$INSTANCE_ID" ]; then
        echo "Failed to launch instance $instance. Skipping."
        continue
    fi

    echo "Launched instance $instance with ID $INSTANCE_ID"

    # Wait until instance is running
    aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"

    # Fetch IP: private for all except frontend (public IP)
    if [ "$instance" == "frontend" ]; then
        IP=$(aws ec2 describe-instances \
            --instance-ids "$INSTANCE_ID" \
            --query 'Reservations[0].Instances[0].PublicIpAddress' \
            --output text)
        echo "Frontend instance has public IP: $IP"
    else
        IP=$(aws ec2 describe-instances \
            --instance-ids "$INSTANCE_ID" \
            --query 'Reservations[0].Instances[0].PrivateIpAddress' \
            --output text)
    fi

    if [ -z "$IP" ]; then
        echo "Could not get IP address for $instance. Skipping DNS update."
        continue
    fi

    echo "$instance -> $IP"

    # Create or update A record in Route 53
    aws route53 change-resource-record-sets \
      --hosted-zone-id "$ZONE_ID" \
      --change-batch "{
        \"Comment\": \"Upserting A record for $instance\",
        \"Changes\": [{
          \"Action\": \"UPSERT\",
          \"ResourceRecordSet\": {
            \"Name\": \"$instance.$DOMAIN_NAME\",
            \"Type\": \"A\",
            \"TTL\": 1,
            \"ResourceRecords\": [{
              \"Value\": \"$IP\"
            }]
          }
        }]
      }"

    echo "DNS record for $instance.$DOMAIN_NAME -> $IP created/updated."

    # Small delay to avoid API throttling
    sleep 2
done
