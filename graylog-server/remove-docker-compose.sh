#!/usr/bin/env bash


docker compose down \
	&& docker container prune \
	&& docker volume rm -f \
	"$USER"_elasticsearch-data-01 \
        "$USER"_elasticsearch-data-02 \
        "$USER"_graylog-data-01 \
        "$USER"_graylog-data-02 \
        "$USER"_graylog-journal-01 \
        "$USER"_graylog-journal-02 \
        "$USER"_mongodb-data-01 \
        "$USER"_mongodb-data-02 \
        "$USER"_mongodb-data-03 \
	&& rm -rf etc \
	&& docker volume prune
