#!/usr/bin/env bash

# exit on error
set -o errexit

if [[ ${USER} != "root" ]]; then
    echo "This script must be run as root!"
    exit 1
fi

if [[ -z ${CCS_ENVIRONMENT} || ${CCS_ENVIRONMENT} == 'switch' ]]; then
    echo "Switch to Tenant Cloud environment"
    exit 1
fi

OSP_RELEASE=HIM1
OSP5_RPMS_VERSION=HIM1.11-*.release.HIM1
OSP6_RPMS_VERSION=HIM1.6-*.release.HIM1
RHEL7_RPMS_VERSION=HIM1.19-*.release.HIM1

# EXAMPLE VERSION: 246-463.release.HIM1
if [ ! -z $1 ]; then
   REDHOUSE_VERSION=$1
else
   REDHOUSE_VERSION=''
fi

# disable colors in ansible output
export ANSIBLE_NOCOLOR=1
export ANSIBLE_FORCE_COLOR=0

# update heighliner cobbler repos and verify installed redhouse version
if [ ! -z "$REDHOUSE_VERSION" ]; then
    /opt/cis/tools/utils/yum_sync.sh -noupdate
    rpm -q service-redhouse-tenant-${REDHOUSE_VERSION} || yum remove -y service-redhouse-tenant && yum install -y service-redhouse-tenant-${REDHOUSE_VERSION}
fi

# pre-staging yum repos
yum remove -y service-rhel-7-server-openstack-5.0-rpms && yum install -y service-rhel-7-server-openstack-5.0-rpms-${OSP5_RPMS_VERSION}

OSP5_EXCLUDE=$(ansible -m ping -f 50 rhel-7-server-openstack-5.0-rpms 2>&1 | awk '/FAILED/ { gsub(/\x1B\[[0-9]+;?[0-9]*m/, ""); s = s":!"$1 } END { print s }')
export HEIGHLINER_DEPLOY_TARGET_HOSTS="rhel-7-server-openstack-5.0-rpms${OSP5_EXCLUDE}"
echo "${HEIGHLINER_DEPLOY_TARGET_HOSTS}"

cd /opt/ccs/services/rhel-7-server-openstack-5.0-rpms
heighliner deploy
yum remove -y service-rhel-7-server-openstack-5.0-rpms

yum remove -y service-rhel-7-server-openstack-6.0-rpms && yum install -y service-rhel-7-server-openstack-6.0-rpms-${OSP6_RPMS_VERSION}

OSP6_EXCLUDE=$(ansible -m ping -f 50 rhel-7-server-openstack-6.0-rpms 2>&1 | awk '/FAILED/ { gsub(/\x1B\[[0-9]+;?[0-9]*m/, ""); s = s":!"$1 } END { print s }')
export HEIGHLINER_DEPLOY_TARGET_HOSTS="rhel-7-server-openstack-6.0-rpms${OSP6_EXCLUDE}"
echo "${HEIGHLINER_DEPLOY_TARGET_HOSTS}";

cd /opt/ccs/services/rhel-7-server-openstack-6.0-rpms
heighliner deploy
yum remove -y service-rhel-7-server-openstack-6.0-rpms

yum remove -y service-rhel-7-server-rpms && yum install -y service-rhel-7-server-rpms-${RHEL7_RPMS_VERSION}

RHEL7_EXCLUDE=$(ansible -m ping -f 50 rhel-7-server-rpms 2>&1 | awk '/FAILED/ { gsub(/\x1B\[[0-9]+;?[0-9]*m/, "");  s = s":!"$1 } END { print s }')
export HEIGHLINER_DEPLOY_TARGET_HOSTS="rhel-7-server-rpms${RHEL7_EXCLUDE}"
echo "${HEIGHLINER_DEPLOY_TARGET_HOSTS}"

cd /opt/ccs/services/rhel-7-server-rpms
heighliner deploy
yum remove -y service-rhel-7-server-rpms

RHV=$(rpm -qa |fgrep service-redhouse-tenant | sed -e "s/^service-redhouse-tenant-//" -e "s/\.x86_64$//")
echo "$(date) pre-stage-${HEIGHLINER_DEPLOY_TARGET_HOSTS} ${OSP_RELEASE} ${RHV} ${OSP5_RPMS_VERSION} ${OSP6_RPMS_VERSION} ${RHEL7_RPMS_VERSION}" >> /etc/redhouse-release
