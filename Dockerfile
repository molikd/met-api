FROM registry.k8s.brgl.org/brgl/perl:0.0.1

COPY . /home/met/met-api

RUN apk update && apk add --no-cache --virtual .build-dependencies make \
	&& cd /home/met/met-api && perl Makefile.PL && make && make test && make install \
	&& cd / \
	&& apk del .build-dependencies \
	&& rm -rf /var/cache/apk/* \
	&& rm -rf /home/met
