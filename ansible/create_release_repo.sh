#!/bin/bash

RELEASE='release-2.3.3'

h=$(hostname -s)
SITE_REPO=`hiera -c /etc/puppet//hiera.yaml site_repo`
REPOS="${SITE_REPO} ccs-secure-repo mongodb rhel-7-server-cisco-rpms rhel-7-server-rpms rhel-7-server-openstack-5.0-rpms rhel-7-server-openstack-6.0-rpms rhel-7-server-qemu-viper-patch percona-centos6 rhel-7-server-hybrid-rpms ccs-artifactory-libguestfs ccs-artifactory-openstack-keystone-hybrid-driver ccs-artifactory-daemonize ccs-artifactory-ccs-repose"

echo > /tmp/${RELEASE}.repo

for i in $REPOS; do
ENABLED=1
if [ $i != "${SITE_REPO}" -a $i != "ccs-secure-repo" -a $i != "rhel-7-server-qemu-viper-patch" -a "$i" != "percona-centos6" -a $i != "mongodb" -a $i != "rhel-7-server-openstack-6.0-rpms" ]
then
  i="${i}_2.3.3"
elif [ $i == "rhel-7-server-openstack-6.0-rpms" ]
then
  ENABLED=0
fi
cat << EOF >> /tmp/${RELEASE}.repo
[${i}]
metadata_expire = 86400
baseurl = http://${h}/cobbler/repo_mirror/${i}/
ui_repoid_vars = basearch
name = Release 2.3.3 ${i}
gpgkey = file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
enabled = ${ENABLED}
gpgcheck = 0
EOF
done
