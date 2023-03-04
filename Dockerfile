ARG RUBY_IMAGE_TAG=3.2.1-alpine3.17
FROM docker.io/ruby:${RUBY_IMAGE_TAG} AS base

FROM base AS dependencies

RUN apk add --update build-base curl git

COPY Gemfile Gemfile.lock ./

RUN bundle config set without "development test" \
  && bundle install --jobs=3 --retry=3 \
  \
  && set -ex; \
    curl -fL https://mirror.openshift.com/pub/rhacs/assets/${ROXCTL_VERSION}/bin/Linux/roxctl -o roxctl \
    && chmod +x roxctl \
    && mv roxctl /usr/local/bin/roxctl

FROM base

ENV APP_HOME=/home/app

RUN apk -U upgrade \
   && apk add gcompat curl \
   && ln -s /opt/cve-finder/cve-finder.rb /usr/bin/cve-finder \
   && mkdir ${APP_HOME} \
   && chown -R 1001:0 ${APP_HOME} \
   && chmod -R g=u ${APP_HOME}

USER 1001

WORKDIR ${APP_HOME}

COPY --from=dependencies /usr/local/bundle/ /usr/local/bundle/

COPY --from=dependencies /usr/local/bin/roxctl /usr/local/bin/roxctl

COPY . /opt/cve-finder

CMD ["cve-finder"]

