FROM debian

RUN apt update && apt install systemctl curl coreutils cron -y \
    && curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-6.3.2-amd64.deb \
    && dpkg -i filebeat-6.3.2-amd64.deb \
    && systemctl enable filebeat.service \
    && apt remove --purge curl systemctl -y \
    && rm -rf filebeat* \
    && apt clean \
    && apt autoremove -y \
    && rm -rf /tmp/*

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY rotate_logs.sh /usr/local/bin/rotate_logs.sh

RUN chmod +x /usr/local/bin/entrypoint.sh \
    && chmod +x /usr/local/bin/rotate_logs.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/bin/filebeat", "-e", "-c", "/usr/share/filebeat/filebeat.yml"]
