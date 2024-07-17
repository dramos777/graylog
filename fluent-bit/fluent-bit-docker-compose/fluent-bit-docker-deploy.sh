#!/bin/env bash

# Diretório onde o script está localizado
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# IP e porta do servidor Graylog
GRAYLOG_SERVER="your_graylog_server_ip"
GRAYLOG_PORT="12201"
LOG_DATA="/var/lib/docker/volumes/compose_teste-logs*/*/*.log"
STATE_FLUENTBIT_DB="/var/lib/docker/containers-state/flb_tail_docker.db"

# Criar o arquivo fluent-bit.conf
cat << EOF > "$SCRIPT_DIR/fluent-bit.conf"
[SERVICE]
    Flush        1
    Daemon       Off
    Log_Level    info
    Parsers_File parsers.conf

[INPUT]
    Name              tail
    Tag               docker.*
    Path              $LOG_DATA
    Parser            docker
    DB                $STATE_FLUENTBIT_DB
    Mem_Buf_Limit     150MB
#    Skip_Long_Lines   On

[FILTER]
    Name                lua
    Match               docker.*
    Script              /fluent-bit/scripts/filter.lua
    Call                Process

[OUTPUT]
    Name         gelf
    Match        *
    Host         $GRAYLOG_SERVER
    Port         $GRAYLOG_PORT
    Gelf_Short_Message_Key log
    Gelf_Full_Message_Key log
    Gelf_Level_Key level
    #    Gelf_Facility kube-fluent-bit
EOF

# Criar o arquivo parsers.conf
cat << EOF > "$SCRIPT_DIR/parsers.conf"
[PARSER]
    Name   docker
    Format regex
    Regex  ^(?<time>[^ ]*)\s(?<stream>stdout|stderr)\s(?<log>.*)$
EOF

# Criar o arquivo filter.lua com a função Process
cat << 'EOF' > "$SCRIPT_DIR/filter.lua"
-- Define a função Process que será chamada pelo Fluent Bit
function Process(tag, timestamp, record)
    -- Garante que cada registro tenha a chave 'short_message'
    if record['short_message'] == nil then
        record['short_message'] = record['log'] or "No log message available"
    end
    
    -- Retorna 0 para indicar que o registro deve ser processado
    return 0, timestamp, record
end
EOF

# Verificar se o container já está em execução
if [ "$(docker ps -q -f name=fluent-bit)" ]; then
    echo "Stopping existing Fluent Bit container..."
    docker stop fluent-bit
fi

# Remover o container se estiver parado
if [ "$(docker ps -aq -f status=exited -f name=fluent-bit)" ]; then
    echo "Removing existing Fluent Bit container..."
    docker rm fluent-bit
fi

# Iniciar o container do Fluent Bit
docker run -d \
    -v /var/lib/docker/volumes/compose_teste-logs:/var/lib/docker/volumes/compose_teste-logs:ro \
    -v /var/lib/docker/volumes/compose_teste-logs3:/var/lib/docker/volumes/compose_teste-logs3:ro \
    -v /var/lib/docker/containers-state:/var/lib/docker/containers-state \
    -v "$SCRIPT_DIR/fluent-bit.conf":/fluent-bit/etc/fluent-bit.conf \
    -v "$SCRIPT_DIR/parsers.conf":/fluent-bit/etc/parsers.conf \
    -v "$SCRIPT_DIR/filter.lua":/fluent-bit/scripts/filter.lua \
    --name fluent-bit \
    fluent/fluent-bit:latest -c /fluent-bit/etc/fluent-bit.conf

echo "Fluent Bit configurado e container iniciado."

