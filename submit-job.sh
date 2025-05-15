#!/bin/bash

# Build the project
mvn clean package

# Set variables
EMR_CLUSTER_ID="j-1U0VBMOSO89KQ"
JAR_FILE="target/flink-rabbitmq-1.0-SNAPSHOT.jar"
MAIN_CLASS="com.example.flink.MySQLToRabbitMQJob"
DATABASE="test"
TABLE="users"
EXCHANGE="mysql_cdc"
ROUTING_KEY="mysql_data"
PEM_FILE="~/iad.pem"
HDFS_CHECKPOINT_PATH="hdfs:///user/hadoop/flink-checkpoints/mysql-rabbitmq-cdc"

# Get the EMR master node DNS
echo "Getting EMR master DNS..."
MASTER_DNS=$(aws emr describe-cluster --cluster-id $EMR_CLUSTER_ID --query 'Cluster.MasterPublicDnsName' --output text)

if [ -z "$MASTER_DNS" ]; then
    echo "Failed to get EMR master DNS. Please check if the cluster is running and you have AWS CLI configured correctly."
    exit 1
fi

echo "EMR Master DNS: $MASTER_DNS"

# Copy the JAR file to the EMR master node
echo "Copying JAR file to EMR master node..."
scp -i $PEM_FILE $JAR_FILE hadoop@$MASTER_DNS:~/

# Create HDFS directory for checkpoints
echo "Creating HDFS directory for checkpoints..."
ssh -i $PEM_FILE hadoop@$MASTER_DNS "hadoop fs -mkdir -p /user/hadoop/flink-checkpoints/mysql-rabbitmq-cdc"

# SSH to EMR master node and submit the job
echo "Submitting Flink job to EMR cluster..."
ssh -i $PEM_FILE hadoop@$MASTER_DNS << EOF
export HADOOP_CLASSPATH=\$(hadoop classpath)
/usr/lib/flink/bin/flink run -m yarn-cluster \
 -yjm 1024m -ytm 2048m \
 -c $MAIN_CLASS \
 ~/flink-rabbitmq-1.0-SNAPSHOT.jar \
 --database $DATABASE \
 --table $TABLE \
 --exchange $EXCHANGE \
 --routing-key $ROUTING_KEY
EOF

echo "Job submitted successfully!"
echo "Checkpoints will be stored at: $HDFS_CHECKPOINT_PATH"
