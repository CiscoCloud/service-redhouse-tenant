#!/bin/bash
#
# Utility script to facilitate High Impact Maintenance on CIS-1.0
#

AGG_NAME=HIM
WORK_DIR=/opt/ccs/services/redhouse-tenant/ansible/HIM/live-migration
MIGRATION_APPDIR=/opt/cis/tools/utils/live-migration
GET_AGG_PY=/opt/cis/tools/utils/get_agg.py
SRC_LIST=$WORK_DIR/source_list
HOST_REGEX=''
ADD_CNT=0

_check_src_list() {
    if [ ! -r "$SRC_LIST" ]; then
        echo "ERROR: Can't read $SRC_LIST"
        exit 1
    fi
    local cnt=$(fgrep -c $HOST_REGEX $SRC_LIST)
    if [ "$cnt" -lt 1 ]; then
        echo "ERROR: Empty $SRC_LIST"
        exit 1
    fi
}

_get_latest_app() {
    if [ -d "$MIGRATION_APPDIR" -a -d "$WORK_DIR" ]; then
        for i in $(ls $MIGRATION_APPDIR/*.py | awk -F\/ '{print $NF}'); do
            #[ "$MIGRATION_APPDIR/$i" -nt "$WORK_DIR/$i" ] && \cp $MIGRATION_APPDIR/$i $WORK_DIR/$i
            \cp $MIGRATION_APPDIR/$i $WORK_DIR/$i
        done
    fi
}

_get_az() {
    local az=$(nova availability-zone-list 2>/dev/null | fgrep -i available | grep -Ev '(internal|nova)' | awk '{print $2}')
    echo "$az"
}
_agg_exists() {
    local exists=$(nova aggregate-list 2>/dev/null | fgrep -c " $AGG_NAME ")
    echo "$exists"
}

_delete_agg() {
    local exists=$(_agg_exists)
    [ "$exists" == "0" ] && return 0
    for i in $(nova aggregate-details $AGG_NAME 2>/dev/null | fgrep " $AGG_NAME " | awk -F\| '{print $5}' | sed s/[\',]//g); do
        nova aggregate-remove-host $AGG_NAME $i >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "ERROR: Failed to remove host $i from $AGG_NAME aggregate"
            exit 1
        fi
    done
    nova aggregate-delete $AGG_NAME >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to delete aggregate $AGG_NAME"
        exit 1
    fi
}

_create_agg() {
    local exists=$(_agg_exists)
    [ "$exists" == "1" ] && return 0
    local az=$(_get_az)
    nova aggregate-create $AGG_NAME $az >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to create aggregate $AGG_NAME in AZ $az"
        exit 1
    fi
}

_list_spares() {
    echo -n
    python $GET_AGG_PY display -a SpareNodes -s enabled | sort | fgrep $HOST_REGEX | fgrep enabled | awk '{print $1}' | awk -F. '{print $1}' | tr '\n' ':'
}

_list_source() {
    _check_src_list
    echo -n
    fgrep $HOST_REGEX $SRC_LIST | awk '{print $1}' | sort | awk -F. '{print $1}' | tr '\n' ':'
}

_populate_from_spare_nodes() {
    _delete_agg
    _create_agg
    for i in $(python $GET_AGG_PY display -a SpareNodes -s enabled | fgrep $HOST_REGEX | awk '{print $1}' | sort); do
        nova aggregate-add-host $AGG_NAME $i >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "ERROR: Failed to add host $i to $AGG_NAME aggregate"
            exit 1
        else
            let ADD_CNT+=1
        fi
    done
}

_populate_from_source_list() {
    _check_src_list
    _delete_agg
    _create_agg
    for i in $(fgrep $HOST_REGEX $SRC_LIST | awk '{print $1}' | sort); do
        nova service-enable $i nova-compute >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "ERROR: Failed to: nova service-enable $i nova-compute"
            exit 1
        fi
        nova aggregate-add-host $AGG_NAME $i >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "ERROR: Failed to remove host $i from $AGG_NAME aggregate"
            exit 1
        else
            let ADD_CNT+=1
        fi
    done
}

_populate_spare_nodes_from_him() {
    TMP_AGG_NAME=$AGG_NAME
    AGG_NAME=SpareNodes
    _create_agg
    AGG_NAME=$TMP_AGG_NAME
    for i in $(python $GET_AGG_PY display -a $AGG_NAME -s all | awk '{print $1}' | awk -F. '{print $1}' | sort); do
        nova aggregate-add-host SpareNodes $i >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "ERROR: Failed to add host $i from $AGG_NAME to SpareNodes aggregate"
            exit 1
        else
            let ADD_CNT+=1
        fi
    done
}

umask 022

if [ ! -z $2 ]; then
   HOST_REGEX=$2
else
   HOST_REGEX='nova'
fi

case "$1" in
'spare_list')
    _get_latest_app
    _list_spares
    exit 0
    ;;
'source_list')
    _list_source
    exit 0
    ;;
'first')
    _get_latest_app
    _populate_from_spare_nodes
    echo "Added $ADD_CNT nodes to $AGG_NAME"
    exit 0
    ;;
'batch')
    _get_latest_app
    _populate_from_source_list
    echo "Added $ADD_CNT nodes to $AGG_NAME"
    exit 0
    ;;
'add_to_spare')
    _populate_spare_nodes_from_him
    echo "Added $ADD_CNT nodes from $AGG_NAME to SpareNodes aggregate"
    exit 0
    ;;
'delete')
    _delete_agg
    exit 0
    ;;
*)
  echo -e "Usage:   $0 <spare_list|first|batch|delete> [nova1|nova2|nova3]\n"
  echo -e "spare_list   - list nodes from SpareNodes aggregate in single line for Ansible \"--limit\""
  echo -e "source_list  - list nodes from source_list file in single line for Ansible \"--limit\""
  echo -e "first        - populate $AGG_NAME aggregate with nodes from SpareNodes aggregate"
  echo -e "batch        - populate $AGG_NAME aggregate with nodes from $SRC_LIST file"
  echo -e "add_to_spare - add nodes in $AGG_NAME aggregate to SpareNodes aggregate"
  echo -e "delete       - delete $AGG_NAME aggregate even if populated with node names"
  echo -e "2nd optional arg: regex filter for node names.  It defaults to just \"nova\" which includes 1,2,3\n"
  echo -e "Example: $0 first nova1\n"
  exit 1
  ;;
esac
exit 0
