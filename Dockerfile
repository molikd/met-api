FROM alpine

WORKDIR /home/met/met-api
COPY . /home/met/met-api

RUN apk update && apk upgrade && apk add curl perl perl-dev make gcc build-base wget postgresql postgresql-dev gnupg

RUN curl -LO https://raw.githubusercontent.com/miyagawa/cpanminus/master/cpanm \
    && chmod +x cpanm \
    && ./cpanm  --notest App::cpanminus \
    && rm -fr ./cpanm /root/.cpanm

ENV PERL_CPANM_OPT --verbose --mirror https://cpan.metacpan.org --mirror-only

RUN cpanm --force YAML Carton Starman Plack Plack::Builder Dancer && cpanm --force Dancer::Plugin::Database && cpanm Dancer::Plugin::Auth::Github && rm -rf ~/.cpanm
RUN cpanm install Switch YAML::XS JSON::XS Plack::Handler::Gazelle && rm -rf ~/.cpanm

RUN apk update && apk add --no-cache --virtual .build-dependencies make perl-test-pod-coverage perl-test-pod

RUN cd /home/met/met-api \
	&& perl Makefile.PL && make \
	# TODO: Add back when testing implemented. && RELEASE_TESTING=1 make test \
	&& cd / \
	&& apk del .build-dependencies \
	&& rm -rf /var/cache/apk/* \
	&& cd /home/met \
	&& mkdir -p /home/met/met-api/logs/var/log/
