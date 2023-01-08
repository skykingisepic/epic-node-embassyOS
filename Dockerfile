FROM alpine:3.17

RUN apk update
RUN apk add --no-cache tini && \
    rm -f /var/cache/apk/*

ADD ./epic-node/target/release/epic-node /usr/local/bin/epic-node
RUN chmod +x /usr/local/bin/epic-node
ADD ./docker_entrypoint.sh /usr/local/bin/docker_entrypoint.sh
RUN chmod a+x /usr/local/bin/docker_entrypoint.sh
ADD ./foundation.json ~/.epic/main
ADD ./epic-server.toml /usr/local/bin
ADD ./chaindata.zip ~/.epic/main
RUN unzip ~/.epic/main/chaindata.zip -d ~/.epic/main
