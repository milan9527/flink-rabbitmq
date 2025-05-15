#!/bin/bash

# RabbitMQ connection details
RABBITMQ_HOST="b-d3c9e07d-8b26-4c74-a6d2-53b4fbfa330f.mq.us-east-1.on.aws"
RABBITMQ_AMQP_PORT="5671"  # AMQP SSL port
RABBITMQ_HTTP_PORT="15671"  # Management API HTTPS port
RABBITMQ_USER="admin"
RABBITMQ_PASS="wAr16dk7&UJM"
RABBITMQ_VHOST="/"
RABBITMQ_EXCHANGE="mysql_cdc"
RABBITMQ_QUEUE="mysql_data_queue"
RABBITMQ_ROUTING_KEY="mysql_data"

# Check if rabbitmqadmin is installed
if ! command -v rabbitmqadmin &> /dev/null; then
    echo "rabbitmqadmin is not installed. Installing..."
    wget https://raw.githubusercontent.com/rabbitmq/rabbitmq-server/master/deps/rabbitmq_management/bin/rabbitmqadmin
    chmod +x rabbitmqadmin
    sudo mv rabbitmqadmin /usr/local/bin/
fi

# Create a queue and bind it to the exchange
echo "Creating queue and binding to exchange..."
rabbitmqadmin --host=$RABBITMQ_HOST --port=$RABBITMQ_HTTP_PORT --ssl \
    --username=$RABBITMQ_USER --password=$RABBITMQ_PASS --vhost=$RABBITMQ_VHOST \
    declare queue name=$RABBITMQ_QUEUE durable=true

rabbitmqadmin --host=$RABBITMQ_HOST --port=$RABBITMQ_HTTP_PORT --ssl \
    --username=$RABBITMQ_USER --password=$RABBITMQ_PASS --vhost=$RABBITMQ_VHOST \
    declare binding source=$RABBITMQ_EXCHANGE destination=$RABBITMQ_QUEUE routing_key=$RABBITMQ_ROUTING_KEY

# List queues to verify setup
echo "Listing queues to verify setup:"
rabbitmqadmin --host=$RABBITMQ_HOST --port=$RABBITMQ_HTTP_PORT --ssl \
    --username=$RABBITMQ_USER --password=$RABBITMQ_PASS --vhost=$RABBITMQ_VHOST \
    list queues

# List exchanges to verify setup
echo "Listing exchanges to verify setup:"
rabbitmqadmin --host=$RABBITMQ_HOST --port=$RABBITMQ_HTTP_PORT --ssl \
    --username=$RABBITMQ_USER --password=$RABBITMQ_PASS --vhost=$RABBITMQ_VHOST \
    list exchanges

# List bindings to verify setup
echo "Listing bindings to verify setup:"
rabbitmqadmin --host=$RABBITMQ_HOST --port=$RABBITMQ_HTTP_PORT --ssl \
    --username=$RABBITMQ_USER --password=$RABBITMQ_PASS --vhost=$RABBITMQ_VHOST \
    list bindings

# Continuously monitor for messages
echo "Starting continuous monitoring of RabbitMQ queue $RABBITMQ_QUEUE..."
echo "Press Ctrl+C to stop monitoring."

while true; do
    message=$(rabbitmqadmin --host=$RABBITMQ_HOST --port=$RABBITMQ_HTTP_PORT --ssl \
        --username=$RABBITMQ_USER --password=$RABBITMQ_PASS --vhost=$RABBITMQ_VHOST \
        get queue=$RABBITMQ_QUEUE ackmode=ack_requeue_false count=1)
    
    if [[ "$message" != *"No items"* ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Received message: $message"
    fi
    
    sleep 2
done
