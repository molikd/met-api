FROM alpine:3.7
RUN apk update && \
    apk add wget && \
    apk add perl && \
    apk add perl-dev && \
    apk add make && \
    apk add g++ && \
    wget https://cpanmin.us/ && \
    perl index.html App::cpanminus && \
    cpanm Dancer2 && \
    rm index.html

WORKDIR /root

