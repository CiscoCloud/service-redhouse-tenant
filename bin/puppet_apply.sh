#!/usr/bin/env bash

usage() {
  echo "USAGE: $0 [options]
    -m  Limit execution to specific machine(s) (required)
    -t  Only run plays and tasks tagged with these values
    -a  Additional arguments to ansible-playbook
    -v  'redhouse_version=0.0.3-96 data_version=1.1.1712-1'
    -h  Display this usage
  "
  exit 1
}

while getopts ":hm:t:a:v:" arg; do
  case ${arg} in
    m) TARGET=${OPTARG};;
    t) TAGS="--tags ${OPTARG}";;
    a) ARGS=${OPTARG};;
    v) VERSION="${OPTARG}";;
    h) usage;;
    ?) echo "Invalid option: -${OPTARG}" >&2; usage;;
  esac
done

[ -z ${TARGET} ] && usage
[ -z "${VERSION}" ] && usage

ansible-playbook ansible/helpers/puppet_apply.yml -e "target_hosts=${TARGET} ${VERSION}" ${TAGS} ${ARGS}
