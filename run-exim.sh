#!/bin/sh

: ${CONFIG_FILE:=$1}
shift

if [[ $(id -u) -eq 0 ]]; then
  : ${EXIM_USER:=exim}
  : ${EXIM_GROUP:=exim}
fi

set -x
exec exim -C "${CONFIG_FILE:-$(realpath "$(dirname "$0")/exim.conf")}" \
  -DLMTP_HOST=localhost \
  -DLMTP_PORT=2525 \
  -DSMTP_PORT=${SMTP_PORT:-25} \
  -DFQDN=${EXIM_FQDN:-$(hostname -f)} \
  -DSPOOL=${EXIM_SPOOL:-/var/spool/exim} \
  -DUID=$(id -u $EXIM_USER) \
  -DGID=$(id -g $EXIM_GROUP) \
  -bdf -q1h "$@"
