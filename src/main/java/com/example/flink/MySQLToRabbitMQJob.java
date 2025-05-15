package com.example.flink;

import com.ververica.cdc.connectors.mysql.source.MySqlSource;
import com.ververica.cdc.connectors.mysql.table.StartupOptions;
import com.ververica.cdc.debezium.JsonDebeziumDeserializationSchema;
import org.apache.flink.api.common.eventtime.WatermarkStrategy;
import org.apache.flink.api.common.restartstrategy.RestartStrategies;
import org.apache.flink.api.common.serialization.SimpleStringSchema;
import org.apache.flink.api.common.time.Time;
import org.apache.flink.runtime.state.filesystem.FsStateBackend;
import org.apache.flink.streaming.api.CheckpointingMode;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.CheckpointConfig;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.functions.sink.SinkFunction;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Properties;
import java.util.concurrent.TimeUnit;
import com.rabbitmq.client.ConnectionFactory;
import com.rabbitmq.client.Connection;
import com.rabbitmq.client.Channel;

/**
 * Flink job that captures MySQL CDC events and sends them to RabbitMQ
 */
public class MySQLToRabbitMQJob {
    private static final Logger LOG = LoggerFactory.getLogger(MySQLToRabbitMQJob.class);

    public static void main(String[] args) throws Exception {
        // Parse command line arguments
        String database = "test";
        String table = "users";
        String rabbitMQExchange = "mysql_cdc";
        String rabbitMQRoutingKey = "mysql_data";

        // Parse arguments if provided
        for (int i = 0; i < args.length; i++) {
            if ("--database".equals(args[i]) && i < args.length - 1) {
                database = args[++i];
            } else if ("--table".equals(args[i]) && i < args.length - 1) {
                table = args[++i];
            } else if ("--exchange".equals(args[i]) && i < args.length - 1) {
                rabbitMQExchange = args[++i];
            } else if ("--routing-key".equals(args[i]) && i < args.length - 1) {
                rabbitMQRoutingKey = args[++i];
            }
        }

        LOG.info("Starting MySQL to RabbitMQ CDC job");
        LOG.info("Database: {}, Table: {}", database, table);
        LOG.info("RabbitMQ Exchange: {}, Routing Key: {}", rabbitMQExchange, rabbitMQRoutingKey);

        // Set up the streaming execution environment
        final StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        
        // Configure checkpointing for fault tolerance
        env.enableCheckpointing(60000); // Checkpoint every 60 seconds
        env.getCheckpointConfig().setCheckpointingMode(CheckpointingMode.EXACTLY_ONCE);
        env.getCheckpointConfig().setMinPauseBetweenCheckpoints(30000); // Min 30 seconds between checkpoints
        env.getCheckpointConfig().setCheckpointTimeout(120000); // Checkpoint timeout after 2 minutes
        env.getCheckpointConfig().setMaxConcurrentCheckpoints(1); // Only one checkpoint at a time
        env.getCheckpointConfig().enableExternalizedCheckpoints(
            CheckpointConfig.ExternalizedCheckpointCleanup.RETAIN_ON_CANCELLATION); // Keep checkpoints on cancel
        
        // Set state backend to HDFS filesystem
        env.setStateBackend(new FsStateBackend("hdfs:///user/hadoop/flink-checkpoints/mysql-rabbitmq-cdc"));
        
        // Configure restart strategy
        env.setRestartStrategy(RestartStrategies.fixedDelayRestart(
            3, // Number of restart attempts
            Time.of(10, TimeUnit.SECONDS) // Delay between attempts
        ));

        // Configure MySQL CDC Source
        Properties debeziumProperties = new Properties();
        debeziumProperties.put("database.serverTimezone", "UTC");
        debeziumProperties.put("include.schema.changes", "false");
        // Add additional Debezium properties for better CDC capture
        debeziumProperties.put("snapshot.mode", "initial");
        debeziumProperties.put("snapshot.locking.mode", "none");
        debeziumProperties.put("decimal.handling.mode", "string");
        debeziumProperties.put("tombstones.on.delete", "false");
        debeziumProperties.put("event.processing.failure.handling.mode", "warn");
        debeziumProperties.put("database.history.store.only.captured.tables.ddl", "true");

        MySqlSource<String> mySqlSource = MySqlSource.<String>builder()
                .hostname("mysql8.c7b8fns5un9o.us-east-1.rds.amazonaws.com")
                .port(3306)
                .databaseList(database)
                .tableList(database + "." + table)
                .username("admin")
                .password("your password")
                .deserializer(new JsonDebeziumDeserializationSchema())
                .startupOptions(StartupOptions.latest()) // Changed from initial() to latest() to capture only new changes
                .debeziumProperties(debeziumProperties)
                .build();

        // Add MySQL CDC source to the environment as a stream
        DataStream<String> mysqlStream = env.fromSource(
                mySqlSource,
                WatermarkStrategy.noWatermarks(),
                "MySQL CDC Source"
        );

        // Add a map operation to log all events for debugging
        DataStream<String> loggedStream = mysqlStream.map(value -> {
            LOG.info("CDC Event received: {}", value);
            return value;
        });

        // Configure RabbitMQ connection
        // For SSL connection to Amazon MQ, we need to use the default SSL context
        System.setProperty("com.rabbitmq.client.ssl.algorithm", "TLSv1.2");
        
        // Create a custom sink function for RabbitMQ
        SinkFunction<String> rabbitMQSink = new RabbitMQSinkFunction(
                "b-d3c9e07d-8b26-4c74-a6d2-53b4fbfa330f.mq.us-east-1.on.aws",
                5671,
                "admin",
                "wAr16dk7&UJM",
                rabbitMQExchange,
                rabbitMQRoutingKey
        );

        // Add sink to the stream
        loggedStream.addSink(rabbitMQSink).name("RabbitMQ Sink");

        // Print the execution plan
        LOG.info("Execution plan: {}", env.getExecutionPlan());

        // Execute the job
        env.execute("MySQL to RabbitMQ CDC Job");
    }

    /**
     * Custom RabbitMQ sink that uses the RabbitMQ client directly
     */
    private static class RabbitMQSinkFunction implements SinkFunction<String> {
        private static final long serialVersionUID = 1L;
        private final String host;
        private final int port;
        private final String username;
        private final String password;
        private final String exchange;
        private final String routingKey;
        
        private transient ConnectionFactory factory;
        private transient Connection connection;
        private transient Channel channel;
        
        public RabbitMQSinkFunction(String host, int port, String username, String password, 
                                 String exchange, String routingKey) {
            this.host = host;
            this.port = port;
            this.username = username;
            this.password = password;
            this.exchange = exchange;
            this.routingKey = routingKey;
        }
        
        private void initializeConnection() throws Exception {
            if (factory == null) {
                LOG.info("Initializing RabbitMQ connection to {}:{}", host, port);
                factory = new ConnectionFactory();
                factory.setHost(host);
                factory.setPort(port);
                factory.setUsername(username);
                factory.setPassword(password);
                factory.setVirtualHost("/");
                factory.useSslProtocol();
                
                connection = factory.newConnection();
                channel = connection.createChannel();
                
                // Declare exchange if it doesn't exist
                channel.exchangeDeclare(exchange, "direct", true);
                
                // Declare a queue and bind it to the exchange
                String queueName = "mysql_data_queue";
                channel.queueDeclare(queueName, true, false, false, null);
                channel.queueBind(queueName, exchange, routingKey);
                
                LOG.info("RabbitMQ connection established to {}:{}", host, port);
            }
        }

        @Override
        public void invoke(String value, Context context) {
            try {
                if (channel == null) {
                    initializeConnection();
                }
                
                // Log the message before sending to RabbitMQ
                LOG.info("Sending message to RabbitMQ: {}", value);
                
                // Publish the message to RabbitMQ
                channel.basicPublish(exchange, routingKey, null, value.getBytes());
                LOG.info("Message sent successfully to exchange: {}, routing key: {}", exchange, routingKey);
            } catch (Exception e) {
                LOG.error("Error sending message to RabbitMQ: {}", e.getMessage(), e);
                // Try to reconnect on next message
                try {
                    if (channel != null) {
                        channel.close();
                    }
                    if (connection != null) {
                        connection.close();
                    }
                } catch (Exception ex) {
                    LOG.error("Error closing RabbitMQ connection: {}", ex.getMessage(), ex);
                }
                channel = null;
                connection = null;
                factory = null;
            }
        }
    }
}
