FROM alpine

RUN apk update && apk upgrade && apk add curl perl perl-dev make gcc build-base wget gnupg

RUN curl -LO https://raw.githubusercontent.com/miyagawa/cpanminus/master/cpanm \
    && chmod +x cpanm \
    && ./cpanm App::cpanminus \
    && rm -fr ./cpanm /root/.cpanm

ENV PERL_CPANM_OPT --verbose --mirror https://cpan.metacpan.org --mirror-only
RUN cpanm Digest::SHA Module::Signature && rm -rf ~/.cpanm
ENV PERL_CPANM_OPT $PERL_CPANM_OPT --verify

RUN cpanm YAML Carton Starman Plack Dancer Dancer::Plugin::Database && rm -rf ~/.cpanm

RUN apk update && apk add --no-cache --virtual .build-dependencies make \
		perl-test-pod-coverage perl-test-pod \
	&& cd /home/met/met-api && perl Makefile.PL && make \
	&& RELEASE_TESTING=1 make test \
	&& make install \
	&& cd / \
	&& apk del .build-dependencies \
	&& rm -rf /var/cache/apk/* \
	&& rm -rf /home/met

COPY . /home/met/met-api
