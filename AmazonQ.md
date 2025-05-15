# Flink Checkpointing Implementation

This document outlines the checkpointing implementation added to the MySQL to RabbitMQ CDC project.

## Checkpointing Configuration

The following checkpointing features have been implemented:

1. **Basic Checkpointing**: Enabled with 60-second intervals
2. **Exactly-Once Processing**: Using `CheckpointingMode.EXACTLY_ONCE`
3. **Checkpoint Timing Controls**:
   - Minimum 30 seconds between checkpoints
   - Checkpoint timeout of 2 minutes
   - Maximum of 1 concurrent checkpoint
4. **Externalized Checkpoints**: Retained on job cancellation
5. **S3 State Backend**: Using `FsStateBackend` pointing to S3
6. **Restart Strategy**: Fixed delay restart with 3 attempts and 10-second delays

## S3 Checkpoint Storage

Checkpoints are stored in:
```
hdfs:///user/hadoop/flink-checkpoints/mysql-rabbitmq-cdc
```

## Benefits of Checkpointing

1. **Fault Tolerance**: Automatic recovery from failures
2. **Exactly-Once Processing**: Guarantees no data loss or duplication
3. **State Management**: Preserves application state across restarts
4. **Long-Running Stability**: Enables continuous operation for extended periods

## Monitoring Checkpoints

To monitor checkpoints:

1. Access the Flink Web UI through the YARN Resource Manager
2. Navigate to the job details page
3. Check the "Checkpoints" tab for statistics and history

## Troubleshooting

Common checkpoint issues:

1. **Checkpoint Timeout**: Increase the checkpoint timeout value
2. **Checkpoint Too Large**: Consider incremental checkpoints
3. **S3 Access Issues**: Verify IAM permissions for the EMR cluster
4. **Checkpoint Failures**: Check logs for specific error messages

## Future Improvements

1. Implement incremental checkpoints for better performance
2. Add checkpoint metrics monitoring
3. Configure savepoint creation for controlled upgrades
