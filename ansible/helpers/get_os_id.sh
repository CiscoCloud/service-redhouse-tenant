#!/usr/bin/bash
function usage {
    echo 'Usage: get_os_id.sh -t <resource_type> -n <resource_name>'
    echo '  Supported resource types: tenant, flavor, instance'
    exit 1
}

while getopts "t:n:" value
do
  case $value in
    n) NAME=$OPTARG;;
    t) TYPE=$OPTARG;;
  esac
done
if [[ $NAME == "" ]];then
  usage
fi

case $TYPE in
  tenant)
    VAR=`keystone tenant-list | awk '/'$NAME'/{print $2}'`
    ;;
  instance)
    VAR=`nova list --all-tenants | awk '/'$NAME'/{print $2}'`
    ;;
  aggregate)
    VAR=`nova aggregate-list | awk '/'$NAME'/{print $2}'`
    ;;
  flavor)
    VAR=`nova flavor-list --all | awk '/'$NAME'/{print $2}'`
    ;;
  *)
    usage
    ;;
esac
echo $VAR
