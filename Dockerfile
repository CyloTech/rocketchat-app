FROM repo.cylo.io/baseimage

ENV MYSQL_ROOT_PASSWORD=mysqlr00t \
    APEX_CALLBACK=false \
    INSTALL_MONGODB=true

ENV RC_VERSION 0.74.3
ENV DEPLOY_METHOD=docker
ENV NODE_ENV=production
ENV HOME=/home/appbox/rocketchat
ENV PORT=80
ENV ROOT_URL=http://localhost/
ENV Accounts_AvatarStorePath=/home/appbox/rocketchat/app/uploads
ENV DB_USER=mongoUser
ENV DB_PASS=mongoPass
ENV MONGO_URL="mongodb://${DB_USER}:${DB_PASS}@localhost:27017/rocketchat?authSource=admin"

RUN apt-get update
RUN apt-get install -y graphicsmagick \
                       python-minimal

ADD deps/nodejs_8.11.3-1nodesource1_amd64.deb /nodejs_8.11.3-1nodesource1_amd64.deb
RUN dpkg -i /nodejs_8.11.3-1nodesource1_amd64.deb

ADD scripts/30_rocketchat.sh /etc/my_init.d/30_rocketchat.sh
RUN chmod +x /etc/my_init.d/30_rocketchat.sh
