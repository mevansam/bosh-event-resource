FROM alpine:latest

RUN apk add --update bash jq && rm -rf /var/cache/apk/*

ENV om_cli_version=0.51.0
ADD https://github.com/pivotal-cf/om/releases/download/${om_cli_version}/om-linux /usr/local/bin/om
RUN chmod +x /usr/local/bin/om

ENV bosh_cli_version=5.4.0
ADD https://github.com/cloudfoundry/bosh-cli/releases/download/v${bosh_cli_version}/bosh-cli-${bosh_cli_version}-linux-amd64 /usr/local/bin/bosh
RUN chmod +x /usr/local/bin/bosh

ADD assets/ /opt/resource/
RUN chmod +x /opt/resource/*
RUN mkdir /opt/resource/logs/