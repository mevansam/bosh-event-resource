#!/bin/bash

payload=$(mktemp $TMPDIR/bosh-deployment-event-resource-request.XXXXXX)

cat > ${payload} <&0

debug=$(jq -r '.source.debug // "[]"' < ${payload})
if [[ $debug == y ]]; then

  if [[ -n $1 ]]; then
    exec 2> >(tee $1/bosh-event-resource.log 2>&1 >/dev/null)
  else
    exec 2> >(tee bosh-event-resource.log 2>&1 >/dev/null)
  fi
  set -x
fi

BOSH_ENVIRONMENT="$(jq -r '.source.target // ""' < ${payload})"

if [[ -n $BOSH_ENVIRONMENT ]]; then
  BOSH_CLIENT="$(jq -r '.source.client // ""' < ${payload})"
  BOSH_CLIENT_SECRET="$(jq -r '.source.client_secret // ""' < ${payload})"
  BOSH_CA_CERT="$(jq -r '.source.ca_cert // ""' < ${payload})"
else

  OPSMAN_HOST="$(jq -r '.source.opsman_host // ""' < ${payload})"
  OPSMAN_USERNAME="$(jq -r '.source.opsman_username // ""' < ${payload})"
  OPSMAN_PASSWORD="$(jq -r '.source.opsman_password // ""' < ${payload})"
  OPSMAN_CLIENT_ID="$(jq -r '.source.opsman_client_id // ""' < ${payload})"
  OPSMAN_CLIENT_SECRET="$(jq -r '.source.opsman_client_secret // ""' < ${payload})"
  OPSMAN_SKIP_SSL_VALIDATION="$(jq -r '.source.skip_ssl_validation // "false"' < ${payload})"

  if [[ $OPSMAN_SKIP_SSL_VALIDATION == 'true' ]]; then
    SKIP_SSL_VALIDATION="--skip-ssl-validation"
  else
    SKIP_SSL_VALIDATION=""
  fi

  BOSH_MANIFEST=$(om $SKIP_SSL_VALIDATION \
    --target "https://$OPSMAN_HOST" \
    --client-id "$OPSMAN_CLIENT_ID" \
    --client-secret "$OPSMAN_CLIENT_SECRET" \
    --username "$OPSMAN_USERNAME" \
    --password "$OPSMAN_PASSWORD" \
    curl --silent \
    --path /api/v0/deployed/director/manifest)

  BOSH_ENVIRONMENT=$(echo "$BOSH_MANIFEST" \
    | jq -r '.instance_groups[] | select(.name == "bosh") | .networks[] | select(.name == "infrastructure") | .static_ips[0]')

  BOSH_CLIENT="ops_manager"
  BOSH_CLIENT_SECRET=$(echo "$BOSH_MANIFEST" \
    | jq -r ".instance_groups[] | select(.name == \"bosh\") | .properties.uaa.clients.ops_manager.secret")

  BOSH_CA_CERT=$(om $SKIP_SSL_VALIDATION \
    --target "https://$OPSMAN_HOST" \
    --client-id "$OPSMAN_CLIENT_ID" \
    --client-secret "$OPSMAN_CLIENT_SECRET" \
    --username "$OPSMAN_USERNAME" \
    --password "$OPSMAN_PASSWORD" \
    certificate-authorities --format json \
    | jq -r '.[] | select(.issuer == "Pivotal") | .cert_pem')
fi

export BOSH_ENVIRONMENT
export BOSH_CLIENT
export BOSH_CLIENT_SECRET
export BOSH_CA_CERT

if [[ -z "${BOSH_ENVIRONMENT}" || -z "${BOSH_CLIENT}" || -z "${BOSH_CLIENT_SECRET}" || -z "${BOSH_CA_CERT}" ]]; then
  echo >&2 "must specify target, client, client_secret and ca_cert"
  exit 1
fi

excluded_deployments=$(jq -r '.source.excluded_deployments // "[]"' < ${payload})
export excluded_deployments

event_source=$(jq -r '.source.event_source // ""' < ${payload})
export event_source

object_type=$(jq -r '.source.object_type // "deployment"' < ${payload})
export object_type

current_version=$(jq -r '.version.last_event // "0"' < ${payload})
previous=$(jq -r '.version.previous // "0"' < ${payload})
