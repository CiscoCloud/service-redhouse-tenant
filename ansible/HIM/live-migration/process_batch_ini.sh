#!/bin/bash
#
# Creates initial, site-specific batch.ini file for live migration process
#

WORK_DIR=/opt/ccs/services/redhouse-tenant/ansible/HIM/live-migration
INI=$WORK_DIR/batch.ini
SRC_LIST=$WORK_DIR/source_list

CF=/etc/nova/nova.conf
TMPF=/tmp/.mkbatch.novacf

_get_latest_app() {
    if [ -d "$MIGRATION_APPDIR" -a -d "$WORK_DIR" ]; then
        for i in $(ls $MIGRATION_APPDIR/*.py | awk -F\/ '{print $NF}'); do
            #[ "$MIGRATION_APPDIR/$i" -nt "$WORK_DIR/$i" ] && \cp $MIGRATION_APPDIR/$i $WORK_DIR/$i
            \cp $MIGRATION_APPDIR/$i $WORK_DIR/$i
        done
    fi
}

_fetch_cf() {
    if [ ! -z "$1" ]; then
        NOVA_HOST=$1
    else
        HVS=$(nova hypervisor-list 2>/dev/null | fgrep 'nova1-' | awk '{print $4}' | sort | head -50)
        for i in $HVS; do
           timeout 1 bash -c "cat < /dev/null > /dev/tcp/$i/22" 2>/dev/null
           if [ $? -eq 0 ]; then
              NOVA_HOST=$i
              break
           fi
        done
    fi
    if [ -z "$NOVA_HOST" ]; then
        echo -e "ERROR: Unable to find working nova1 host to grab nova.conf\n"
        echo -e "  Use: $0 <nova_host_name>\n"
        exit 1
    fi
    scp ${NOVA_HOST}:${CF} $TMPF > /dev/null 2>&1
    [ $? -eq 0 ] && chmod 0600 $TMPF
}

_new_ini() {
cat << _EOF_ > $INI
[host]
az=
batch:
_EOF_
for i in $(cat $SRC_LIST | awk '{print $1}' | sort); do
    echo -e "\t$i" >> $INI
done
cat << _EOF_ >> $INI
[target]
agg=HIM
[database]
name=evacuate
[oversubscribe]
agg=
[rabbit]
rabbit_host=
rabbit_userid=
rabbit_password=
[config]
retries=5
_EOF_
}

if [ -z "$OS_REGION" ]; then
    echo "ERROR: Must use \"switch <site-name>\" before running this!"
    exit 1
fi

[ -r "$TMPF" ] || _fetch_cf

if [ ! -r "$TMPF" ]; then
    echo "ERROR: Can't read $TMPF"
    exit 1
fi

_get_latest_app
_new_ini

RABBIT_HOST=$(grep "^rabbit_hosts=" $TMPF | sed s/^rabbit_hosts/rabbit_host/)
RABBIT_USERID=$(grep "^rabbit_userid=" $TMPF)
RABBIT_PASSWORD=$(grep "^rabbit_password=" $TMPF)
AZ=$(nova availability-zone-list 2>/dev/null | fgrep available | grep -Ev '(internal|nova)' | awk '{print $2}')
SUB_AGG=$(nova aggregate-list 2>/dev/null | fgrep Micro | awk '{print $4}')

if [ -z "$AZ" ]; then
    echo "ERROR: Failed to get \"az\""
    exit 1
fi
if [ -z "$SUB_AGG" ]; then
    echo "ERROR: Failed to get \"agg\""
    exit 1
fi

sed -i -e s/^az=.*/az=$AZ/ \
       -e s/^name=.*/name=evacuate/ \
       -e s/^agg=$/agg=$SUB_AGG/ \
       -e s/^rabbit_host.*/$RABBIT_HOST/ \
       -e s/^rabbit_userid.*/$RABBIT_USERID/ \
       -e s/^rabbit_password.*/$RABBIT_PASSWORD/ $INI

[ -r "$INI" ] && echo "Created $INI" >&2
exit 0
