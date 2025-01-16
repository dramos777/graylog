#!/usr/bin/env bash

# Nginx variables
CERTDIR="./etc/nginx/certs/"
NGINXDIR="./etc/nginx/"
NGINXCONF_F="./etc/nginx/nginx.conf"
KEYNAME="privkey.pem"
CERTNAME="fullchain.pem"
DHNAME="dhparam.pem"
VALID="1095"
INTERMEDIATE_KEY="intermediate_key.pem"
INTERMEDIATE_REQ="intermediate_req.pem"
SUBJ="/C=BR/O=Your compane name/CN=Intermediate Certificate"
INTERMEDIATE_CERT="intermediate_cert.pem"
CHAIN="chain.pem"

# MongoDB variables
MONGODIR="./etc/mongodb/"
INITDBDIR="./etc/mongodb/initdb.d/"
INITREPLSETSH="init-replset.sh"
INITREPLSETJS="init-replset.js"

# Graylog variables
GRAYLOGSRV1="graylog1"
GRAYLOGSRV2="graylog2"

# Functions
# Create certs function
Cert_and_dhparam_create() {
    # Generate private key and testened certificate
    if openssl req -newkey rsa:2048 -nodes -keyout "certs/${KEYNAME}" -x509 -days "${VALID}" -out "certs/${CERTNAME}"; then
        echo "Chave privada e certificado autoassinado gerados com sucesso."
    else
        echo "Erro ao gerar chave privada e certificado autoassinado."
        return 1
    fi

    # Generate private key and CSR for the intermediate certificate
    if openssl req -new -keyout "certs/${INTERMEDIATE_KEY}" -out "certs/${INTERMEDIATE_REQ}" -subj "${SUBJ}"; then
        echo "Chave privada e CSR para certificado intermediário gerados com sucesso."
    else
        echo "Erro ao gerar chave privada e CSR para certificado intermediário."
        return 1
    fi

    # Sign the intermediate certificate with self testened certificate
    if openssl x509 -req -days "${VALID}" -in "certs/${INTERMEDIATE_REQ}" -CA "certs/${CERTNAME}" -CAkey "certs/${KEYNAME}" -CAcreateserial -out "certs/${INTERMEDIATE_CERT}"; then
        echo "Certificado intermediário assinado com sucesso."
    else
        echo "Erro ao assinar certificado intermediário com o certificado autoassinado."
        return 1
    fi

    # Generate chain.pem file concatenating certificate self testened and intermediate certificate
    if cat "certs/${CERTNAME}" "certs/${INTERMEDIATE_CERT}" > "certs/${CHAIN}"; then
        echo "Arquivo chain.pem criado com sucesso."
    else
        echo "Erro ao criar arquivo chain.pem."
        return 1
    fi

    # Generate parameters Diffie-Hellman
    if openssl dhparam -out "certs/${DHNAME}" 2048; then
        echo "Parâmetro Diffie-Hellman gerado com sucesso."
    else
        echo "Erro ao gerar parâmetro Diffie-Hellman!"
        return 1
    fi

    echo "Certificado e parâmetro Diffie-Hellman gerados com sucesso."
    return 0
}

# Generate nginx.conf file
Nginx_conf () {
	cat << EOF > "$NGINXCONF_F"
user                 nginx;
pid                  /var/run/nginx.pid;
worker_processes     auto;
worker_rlimit_nofile 65535;

events {
    multi_accept       on;
    worker_connections 65535;
}
 
http {
    charset                utf-8;
    sendfile               on;
    tcp_nopush             on;
    tcp_nodelay            on;
    server_tokens          off;
    log_not_found          off;
    types_hash_max_size    2048;
    types_hash_bucket_size 64;
    client_max_body_size   16M;

    # Logging
    access_log             /var/log/nginx/access.log;
    error_log              /var/log/nginx/error.log warn;

    # SSL
    ssl_session_timeout    1d;
    ssl_session_cache      shared:SSL:10m;
    ssl_session_tickets    off;

    # Diffie-Hellman parameter for DHE ciphersuites
    ssl_dhparam            /etc/nginx/dhparam.pem;

    # Mozilla Intermediate configuration
    ssl_protocols          TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers            EECDH+AESGCM:EDH+AESGCM;
    ssl_ecdh_curve secp384r1;

    # OCSP Stapling
    ssl_stapling           on;
    ssl_stapling_verify    on;

    resolver 8.8.8.8 valid=300s;
    resolver_timeout 5s;

# Disable strict transport security for now. You can uncomment the following
# line if you understand the implications.
#add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload";
add_header X-Frame-Options DENY;
add_header X-Content-Type-Options nosniff;
add_header X-XSS-Protection "1; mode=block";

    # Load balancing configuration
    upstream graylog {
        server graylog1:9000;
        server graylog2:9000;
    }

    # NGINX server block for HTTP
    server {
        listen *:80;
        location / {
            proxy_pass http://graylog;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        # Redirect all HTTP traffic to HTTPS
        return 301 https://\$host\$request_uri;
    }

    # NGINX server block for HTTPS
    server {
        listen 443 ssl;

        ssl_certificate     /etc/nginx/certs/fullchain.pem;
        ssl_certificate_key /etc/nginx/certs/privkey.pem;

        location / {
            proxy_pass http://graylog;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }
}

stream {
    upstream graylog_syslog_tcp {
        server graylog1:1514 max_fails=3 fail_timeout=30s;
        server graylog2:1514 max_fails=3 fail_timeout=30s;
    }

    server {
        listen 1514;
        proxy_pass graylog_syslog_tcp;
        proxy_timeout 3s;
        error_log /var/log/nginx/graylog_syslog_tcp_error.log;
    }

    upstream graylog_syslog_udp {
        server graylog1:1514 max_fails=3 fail_timeout=30s;
        server graylog2:1514 max_fails=3 fail_timeout=30s;
    }

    server {
        listen 1514 udp reuseport;
        proxy_pass graylog_syslog_udp;
        proxy_timeout 3s;
        error_log /var/log/nginx/graylog_syslog_udp_error.log;
    }

    upstream graylog_gelf_tcp {
        server graylog1:12201 max_fails=3 fail_timeout=30s;
        server graylog2:12201 max_fails=3 fail_timeout=30s;
    }

    server {
        listen 12201;
        proxy_pass graylog_gelf_tcp;
        proxy_timeout 3s;
        error_log /var/log/nginx/graylog_gelf_tcp_error.log;
    }

    upstream graylog_gelf_udp {
        server graylog1:12201 max_fails=3 fail_timeout=30s;
        server graylog2:12201 max_fails=3 fail_timeout=30s;
    }

    server {
        listen 12201 udp reuseport;
        proxy_pass graylog_gelf_udp;
        proxy_timeout 3s;
        error_log /var/log/nginx/graylog_gelf_udp_error.log;
    }

    upstream graylog_beats_tcp_5044 {
        server graylog1:5044 max_fails=3 fail_timeout=30s;
        server graylog2:5044 max_fails=3 fail_timeout=30s;
    }

    server {
        listen 5044;
        proxy_pass graylog_beats_tcp_5044;
        proxy_timeout 3s;
        error_log /var/log/nginx/graylog_beats_tcp_5044_error.log;
    }
}

EOF

}

# Main script logic
main() {
    # Ensure directories exist or create them
    if [ ! -d "certs" ]; then
        mkdir -p "certs" || { echo "Erro ao criar diretório: ./certs"; exit 1; }
    fi

    if [ ! -d "$CERTDIR" ]; then
        mkdir -p "$CERTDIR" || { echo "Erro ao criar diretório: $CERTDIR"; exit 1; }
    fi

    if [ ! -d "$NGINXDIR" ]; then
        mkdir -p "$NGINXDIR" || { echo "Erro ao criar diretório: $NGINXDIR"; exit 1; }
    fi

    # Generate certificates and nginx.conf
    Cert_and_dhparam_create || { echo "Erro ao gerar certificados e parâmetros"; exit 1; }
    Nginx_conf || { echo "Erro ao gerar nginx.conf"; exit 1; }

    # Set permissions
    chmod -w $PWD/certs/* || { echo "Erro ao definir permissões em ./certs/"; exit 1; }
    cp -R $PWD/certs/$DHNAME $NGINXDIR \
    &&  cp -R $PWD/certs/* $CERTDIR \
    && rm -rfi $PWD/certs/

    echo "Script concluído com sucesso!"
}

# Run main function
main

