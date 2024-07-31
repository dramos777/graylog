#!/usr/bin/env bash

# Setting up cron variable
CRON_SCHEDULE=${CRON_SCHEDULE:-"0 0 * * *"}
# Directory where logs are stored
LOGROTATE_PATH=${LOGROTATE_PATH:-/var/log}
# Maximum log file size in bytes (1 MB = 1048576 bytes)
LOGROTATE_SIZE=${LOGROTATE_SIZE:-1048576}
# Maximum number of rotated log files
LOGROTATE_ROTATE=${LOGROTATE_ROTATE:-2}

# Configuration of filebeat by variables
cat << EOF > /usr/share/filebeat/filebeat.yml
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - ${FILEBEAT_PATH:-"/var/log"}
  encoding: ANSI_X3.4-1968

output.elasticsearch:
  enabled: false

output.beats:
  enabled: false

output.gelf:
  enabled: false

output.kafka:
  enabled: false

output.amqp:
  enabled: false

output.redis:
  enabled: false

output.splunk_hec:
  enabled: false

output.syslog:
  enabled: false

output.logstash:
  enabled: true
  hosts: ["${OUTPUT_LOGSTASH_HOSTS:-"172.16.0.2"}:${LOGSTASH_PORT:-"5044"}"]
EOF

# Directory where logs are stored
echo 'LOGROTATE_PATH='${LOGROTATE_PATH} > /etc/cron.d/logrotate
# Maximum log file size in bytes (1 MB = 1048576 bytes)
echo 'LOGROTATE_SIZE='${LOGROTATE_SIZE} >> /etc/cron.d/logrotate
# Maximum number of rotated log files
echo 'LOGROTATE_ROTATE='${LOGROTATE_ROTATE} >> /etc/cron.d/logrotate
# Write out the cron job to a temporary file
echo "$CRON_SCHEDULE /usr/local/bin/rotate_logs.sh" >> /etc/cron.d/logrotate

# Give execution rights on the cron job
chmod 0644 /etc/cron.d/logrotate
chmod +x /usr/local/bin/rotate_logs.sh

# Apply the cron job
crontab /etc/cron.d/logrotate

# Start the cron service
cron

# Starts Filebeat
/usr/bin/filebeat -e -c /usr/share/filebeat/filebeat.yml

