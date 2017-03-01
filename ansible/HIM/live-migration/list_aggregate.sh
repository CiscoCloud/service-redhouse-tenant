#!/bin/bash
#
# Lists hosts in an aggregate
# Aggregate name must be 1st argument on command line
# Aggregate must exist
#

AGG_NAME=''

_usage() {
  echo -e "Usage:   $0 <aggregate_name>\n"
  echo -e "Example: $0 HIM"
  echo -e "NOTE:     Aggregate must exist\n"
  exit 1
}

_agg_exists() {
    local exists=$(nova aggregate-list 2>/dev/null | fgrep -c " $AGG_NAME ")
    echo "$exists"
}

[ "$1" != '' ] || _usage
AGG_NAME=$1
EXISTS=$(_agg_exists)
[ "$EXISTS" != "0" ] || _usage

for i in $(nova aggregate-details $AGG_NAME 2>/dev/null | fgrep " $AGG_NAME " | awk -F\| '{print $5}' | sed s/[\',]//g); do
    echo $i
done
