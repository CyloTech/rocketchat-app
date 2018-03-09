FROM ubuntu:16.04
MAINTAINER Gavin Hanson <gavin@cylo.io>

# Optional Configuration Parameter
ARG SERVICE_USER
ARG SERVICE_HOME
ARG SERVICE_PORT
ARG SERVICE_LOGFILE
ARG SERVICE_LOGLEVEL

# Default Settings
ENV DEBIAN_FRONTEND noninteractive
ENV SERVICE_USER ${SERVICE_USER:-mongo}
ENV SERVICE_HOME ${SERVICE_HOME:-/data/db}
ENV SERVICE_PORT ${SERVICE_PORT:-27017}
ENV SERVICE_LOGFILE ${SERVICE_LOGFILE:-/data/logs/mongod.log}
ENV SERVICE_LOGLEVEL ${SERVICE_LOGLEVEL:-v}

ENV RC_VERSION 0.63.0-develop
ENV DEPLOY_METHOD=docker
ENV NODE_ENV=production
ENV HOME=/data/tmp
ENV PORT=80
ENV ROOT_URL=http://localhost/
ENV Accounts_AvatarStorePath=/data/app/uploads

# Install MongoDB & Supervisor
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10 && \
    echo "deb http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.2 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-3.2.list
RUN apt-get update && \
    apt-get install -y --force-yes pwgen \
                                   mongodb-org \
                                   mongodb-org-server \
                                   mongodb-org-shell \
                                   mongodb-org-mongos \
                                   mongodb-org-tools \
                                   supervisor \
                                   net-tools \
                                   curl \
                                   pwgen \
                                   graphicsmagick && \
    echo "mongodb-org hold" | dpkg --set-selections && echo "mongodb-org-server hold" | dpkg --set-selections && \
    echo "mongodb-org-shell hold" | dpkg --set-selections && \
    echo "mongodb-org-mongos hold" | dpkg --set-selections && \
    echo "mongodb-org-tools hold" | dpkg --set-selections

# Install NodeJS & NPM
RUN curl -sL https://deb.nodesource.com/setup_8.x | bash -; \
    apt-get install -y nodejs

ADD configs/supervisord.conf /etc/supervisord.conf
ADD scripts/entrypoint.sh /entrypoint.sh
ADD scripts/configmongo.sh /configmongo.sh
RUN chmod +x /*.sh

EXPOSE 80

CMD [ "/entrypoint.sh" ]