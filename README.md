# MySQL to RabbitMQ CDC with Apache Flink

This project demonstrates how to use Apache Flink with CDC (Change Data Capture) to sync data from a MySQL RDS database to Amazon MQ (RabbitMQ) in real-time. The implementation includes checkpointing for fault tolerance and exactly-once processing guarantees.

## Architecture

```
MySQL RDS → Flink CDC Source → Flink Processing → RabbitMQ Sink → Amazon MQ
                                      ↓
                             S3 Checkpoint Storage
```

## Prerequisites

- Java 11+
- Maven
- AWS CLI configured
- Access to the EMR cluster (j-1U0VBMOSO89KQ)
- Access to MySQL RDS instance
- Access to Amazon MQ (RabbitMQ)

## Project Structure

- `src/main/java/com/example/flink/MySQLToRabbitMQJob.java`: Main Flink job
- `src/main/java/com/example/flink/model/User.java`: User model class
- `setup-mysql.sql`: SQL script to set up the MySQL database
- `submit-job.sh`: Script to build and submit the Flink job to EMR
- `test-mysql.sh`: Script to test MySQL operations
- `monitor-rabbitmq.sh`: Script to monitor RabbitMQ messages

## Setup Instructions

### 1. Set up MySQL Database

Run the provided SQL script to create the test database and users table:

```bash
mysql -h mysql8.c7b8fns5un9o.us-east-1.rds.amazonaws.com -u admin -p < setup-mysql.sql
```

### 2. Build the Project

```bash
mvn clean package
```

### 3. Submit the Flink Job to EMR

Make the script executable and run it:

```bash
chmod +x submit-job.sh
./submit-job.sh
```

### 4. Test Data Changes

Make the script executable and run it:

```bash
chmod +x test-mysql.sh
./test-mysql.sh
```

Use this interactive script to insert, update, or delete users in the MySQL database.

### 5. Monitor RabbitMQ Messages

Make the script executable and run it:

```bash
chmod +x monitor-rabbitmq.sh
./monitor-rabbitmq.sh
```

Use this script to monitor messages arriving in RabbitMQ.

## Configuration Details

### MySQL RDS
- Host: mysql8.c7b8fns5un9o.us-east-1.rds.amazonaws.com
- User: admin
- Database: test
- Table: users

### Amazon MQ (RabbitMQ)
- Host: b-d3c9e07d-8b26-4c74-a6d2-53b4fbfa330f.mq.us-east-1.on.aws
- Port: 5671 (SSL)
- User: admin
- Exchange: mysql_cdc
- Routing Key: mysql_data
- Queue: mysql_data_queue

### EMR Cluster
- Cluster ID: j-1U0VBMOSO89KQ
- Flink Version: 1.16.0
- SSH Key: ~/.ssh/iad.pem

## Troubleshooting

### Common Issues

1. **Connection to MySQL fails**:
   - Verify that the security group allows connections from your IP and the EMR cluster
   - Check that the MySQL user has the necessary permissions

2. **Connection to RabbitMQ fails**:
   - Verify SSL settings
   - Check that the user has the necessary permissions
   - Ensure the exchange exists

3. **Flink job fails**:
   - Check the YARN application logs
   - Verify that the EMR cluster has the necessary permissions to access MySQL and RabbitMQ

### Viewing Logs

To view the Flink job logs:

```bash
ssh -i ~/.ssh/iad.pem hadoop@$(aws emr describe-cluster --cluster-id j-1U0VBMOSO89KQ --query 'Cluster.MasterPublicDnsName' --output text)
yarn logs -applicationId <application_id>
```
