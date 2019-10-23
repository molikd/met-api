FROM registry.k8s.brgl.org/brgl/perl:0.0.1

COPY . /home/met/met-api

RUN apk update && apk add --no-cache --virtual .build-dependencies make \
		perl-test-pod-coverage perl-test-pod \
	&& cd /home/met/met-api && perl Makefile.PL && make \
	&& RELEASE_TESTING=1 make test \
	&& make install \
	&& cd / \
	&& apk del .build-dependencies \
	&& rm -rf /var/cache/apk/* \
	&& rm -rf /home/met
