# This image includes the mysql image preloaded with the dataset
FROM mysql:8.0

# Set database credentials
ENV MYSQL_DATABASE=cbioportal \
    MYSQL_USER=cbio_user \
    MYSQL_PASSWORD=somepassword \
    MYSQL_ROOT_PASSWORD=somepassword

# Copy database dump
ARG DUMP_PATH
COPY ${DUMP_PATH} /docker-entrypoint-initdb.d/database_dump.sql

# Add list of included studies to image metadata. TODO: This should be automated to pull in study names from dump file instead of manually asking for ARGS.
ARG STUDY_NAMES
LABEL studies="${STUDY_NAMES}"

# Expose the connection port
EXPOSE 3306
