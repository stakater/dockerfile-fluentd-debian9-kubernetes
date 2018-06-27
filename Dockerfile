FROM stakater/fluentd-debian9:1.2.2-0.0.1
LABEL maintainer="Stakater Team"
LABEL Description="Fluentd docker image atop Debian9 to run on Kubernetes"

ENV KUBEGEN_CONF_TEMPLATE=kube-gen.conf.tpl
ENV KUBEGEN_CONF=kube-gen.conf
ENV PATH /fluentd/vendor/bundle/ruby/2.3.0/bin:$PATH
ENV GEM_PATH /fluentd/vendor/bundle/ruby/2.3.0
ENV GEM_HOME /fluentd/vendor/bundle/ruby/2.3.0
# skip runtime bundler installation
ENV FLUENTD_DISABLE_BUNDLER_INJECTION 1

ARG DEBIAN_FRONTEND=noninteractive

USER root

WORKDIR /home/fluent

COPY Gemfile* /fluentd/
  RUN buildDeps="sudo make gcc g++ libc-dev ruby-dev libffi-dev" \
     && apt-get update \
     && apt-get upgrade -y \
     && apt-get install \
     -y --no-install-recommends \
     $buildDeps libjemalloc1 \
     ruby-bundler wget procps \
     && cd /tmp \
     && wget https://github.com/stakater/kube-gen/releases/download/0.3.6/kube-gen \
     && mkdir -p /kubegen/ \
     && mv /tmp/kube-gen /usr/local/bin/kube-gen \
     && chmod +x /usr/local/bin/kube-gen \
    && bundle config silence_root_warning true \
    && bundle install --gemfile=/fluentd/Gemfile --path=/fluentd/vendor/bundle \
    && SUDO_FORCE_REMOVE=yes \
    apt-get purge -y --auto-remove \
                  -o APT::AutoRemove::RecommendsImportant=false \
                  $buildDeps \
 && rm -rf /var/lib/apt/lists/* \
    && gem sources --clear-all \
    && rm -rf /tmp/* /var/tmp/* /usr/lib/ruby/gems/*/cache/*.gem

# Copy configuration files
COPY ./conf/*.conf /fluentd/etc/
COPY ./${KUBEGEN_CONF_TEMPLATE} /fluentd/etc/template/

# Copy scripts
COPY ./fluentd-runner.sh /fluentd/etc/scripts/
COPY entrypoint.sh /fluentd/entrypoint.sh

# Copy plugins
COPY plugins /fluentd/plugins/

# Environment variables
ENV FLUENTD_OPT=""
ENV FLUENTD_CONF="fluent.conf"

# See https://packages.debian.org/stretch/amd64/libjemalloc1/filelist
ENV LD_PRELOAD="/usr/lib/x86_64-linux-gnu/libjemalloc.so.1"

# Overwrite ENTRYPOINT to run fluentd as root for /var/log / /var/lib
ENTRYPOINT ["/fluentd/entrypoint.sh"]