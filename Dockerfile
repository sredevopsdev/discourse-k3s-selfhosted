ARG from=discourse/base
ARG tag=slim
ARG DISCOURSE_VERSION=test-passed

FROM $from:$tag

ENV RAILS_ENV=production \
    DISCOURSE_SERVE_STATIC_ASSETS=true \
    EMBER_CLI_COMPILE_DONE=1 \
    EMBER_CLI_PROD_ASSETS=1 \
    RUBY_GLOBAL_METHOD_CACHE_SIZE=131072 \
    RUBY_GC_HEAP_GROWTH_MAX_SLOTS=40000 \
    RUBY_GC_HEAP_INIT_SLOTS=400000 \
    RUBY_GC_HEAP_OLDOBJECT_LIMIT_FACTOR=1.5 \
    RUBY_GC_MALLOC_LIMIT=90000000


# jq needed to create kubernetes CM
RUN apt-get update && apt-get install -y jq

WORKDIR /var/www/discourse

RUN git config --global --add safe.directory /var/www/discourse &&\
    git remote set-branches --add origin ${DISCOURSE_VERSION} &&\
    git fetch --depth 1 origin ${DISCOURSE_VERSION} &&\
    sudo -u discourse bundle config --local deployment true &&\
    sudo -u discourse bundle config --local path ./vendor/bundle &&\
    sudo -u discourse bundle config --local without test development &&\
    sudo -u discourse bundle install --jobs 4 &&\
    sudo -u discourse yarn install --production &&\
    sudo -u discourse yarn cache clean &&\
    bundle exec rake maxminddb:get &&\
    find /var/www/discourse/vendor/bundle -name tmp -type d -exec rm -rf {} + &&\
    chown -R discourse:discourse /var/www/discourse

COPY install /tmp/install

USER discourse

RUN cd /var/www/discourse/plugins \
 && for plugin in $(cat /tmp/install/plugin-list); do \
      git clone $plugin; \
    done

RUN  cd app/assets/javascripts/discourse && \
     /var/www/discourse/app/assets/javascripts/node_modules/.bin/ember build -prod

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
