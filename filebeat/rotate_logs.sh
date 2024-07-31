#!/usr/bin/env bash

# Directory where logs are stored
#LOGROTATE_PATH=${LOGROTATE_PATH:-/opt/jboss/server/default/log/}
# Maximum log file size in bytes (1 MB = 1048576 bytes)
#LOGROTATE_SIZE=${LOGROTATE_SIZE:-1048576}
# Maximum number of rotated log files
#LOGROTATE_ROTATE=${LOGROTATE_ROTATE:-2}

# Function to rotate the logs
rotate_logs() {
    local log_file=$1
    local log_prefix=$(basename "$log_file")

    # Check the size of the log file
    LOG_SIZE=$(stat -c%s "$log_file")

    # If the log file size exceeds the limit, proceed with rotation
    if [[ $LOG_SIZE -ge $LOGROTATE_SIZE ]]; then
        # Rename existing log files
        for ((i = LOGROTATE_ROTATE - 1; i >= 1; i--)); do
            if [[ -f "${log_file}.${i}" ]]; then
                mv "${log_file}.${i}" "${log_file}.$((i + 1))"
            fi
        done

        # Rename the main log file
        cp "$log_file" "${log_file}.1"
        chmod 0640 "${log_file}.1"

        # Empty the $log_file
        echo -n "" > "$log_file"
    fi
}

# Navigate to the log directory
cd "$LOGROTATE_PATH" || { echo "Error: Unable to access directory $LOGROTATE_PATH"; exit 1; }

# Iterate over all .log files in the directory
for log_file in "$LOGROTATE_PATH"/*.log; do
    if [[ -f "$log_file" ]]; then
        rotate_logs "$log_file"
    fi
done
