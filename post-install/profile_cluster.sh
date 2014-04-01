#!/bin/bash
# dgomerman@maprtech.com 2014-Mar-25
# Variables
DATE=$(date +%Y%m%d%H%M)
GEN_PROFILE="gen_profile.sh"
CLUSH_TT_GROUP="tt"
CLUSH_DEST="/tmp/tera_profile"
GEN_PROFILE_OUTPUT="/tmp/node_profile.sh"
OUTPUT_DIR="/tmp/profile_results.$$"
RESULTS_DIR="$OUTPUT_DIR/node_results"
CLUSTER_OUTPUT="$OUTPUT_DIR/cluster_profile.ini"
CLUSTER_ZIP="/tmp/cluster-profile-$DATE.tar.gz"
TERA_SCRIPT="runTeraTune.sh"
TERA_LOG="$OUTPUT_DIR/teraTune.log"

# Functions
pcheck() {
    local p="$1"
    which "$p" >/dev/null 2>&1
    local pE=$?
    if [ $pE -ne 0 ] ; then
        echo "ERROR: $p does not exist. Exiting."
        exit 1
    fi
}

# Pre-checks
pcheck clush
pcheck maprcli

if [ ! -e "$GEN_PROFILE" ] ; then
    echo "ERROR: $GEN_PROFILE script is missing. Exiting."
    exit 1
fi

if [ -d "$RESULTS_DIR" ] ; then
    mv "$RESULTS_DIR" "$RESULTS_DIR.bk"
fi
mkdir -p "$RESULTS_DIR"

# Copy gen_profile.sh script to all nodes
clush -g "$CLUSH_TT_GROUP" "mkdir -p \"$CLUSH_DEST\""
clush -g "$CLUSH_TT_GROUP" --copy "$GEN_PROFILE" --dest "$CLUSH_DEST"
# Run gen_profile.sh script on all Task Tracker nodes
clush -g "$CLUSH_TT_GROUP" -B "$CLUSH_DEST/$GEN_PROFILE"
# Collect gen_profile.sh results from all nodes
clush -g "$CLUSH_TT_GROUP" --rcopy "$GEN_PROFILE_OUTPUT" --dest "$RESULTS_DIR"
# Remote cleanup
#clush -g "$CLUSH_TT_GROUP" "rm -rf \"$CLUSH_DEST\""
#clush -g "$CLUSH_TT_GROUP" "rm -f \"$GEN_PROFILE_OUTPUT\""
# Analyze results
c_node_distro="unknown"
c_node_manufacturer="unknown"
c_node_product="unknown"
c_node_dims_total=0
c_node_dims_avg=0
c_node_memory_total=0
c_node_memory_avg=0
c_node_core_total=0
c_node_core_avg=0
c_node_cpu_mhz_total=0
c_node_cpu_mhz_avg=0
c_node_nic_avg_speed_total=0
c_node_nic_avg_speed_avg=0
c_node_nic_agg_speed_total=0
c_node_nic_agg_speed_avg=0
c_node_nic_count_total=0
c_node_nic_count_avg=0
c_node_disk_count_total=0
c_node_disk_count_avg=0

count=0
homogenous=1
cat <<EOF > $CLUSTER_OUTPUT
; This file is auto generated by MapR profile_cluster.sh

EOF

cd "$RESULTS_DIR"
files=$(find node_profile.sh* -maxdepth 1 -type f)
for f in $files ; do
    # Save old values to check for homogenous cluster
    MEMORY_DIMS_P=$MEMORY_DIMS
    MEMORY_TOTAL_P=$MEMORY_TOTAL
    CORE_COUNT_P=$CORE_COUNT
    CPU_MHZ_P=$CPU_MHZ
    AVG_NIC_SPEED_P=$AVG_NIC_SPEED
    AGG_NIC_SPEED_P=$AGG_NIC_SPEED
    NIC_COUNT_P=$NIC_COUNT
    DISK_COUNT_P=$DISK_COUNT
    
    # Clear old values in case future values are blank
    unset DISTRO
    unset MANUFACTURER
    unset PRODUCT
    unset MEMORY_DIMS
    unset MEMORY_TOTAL
    unset CORE_COUNT
    unset CPU_MHZ
    unset NIC_SPEEDS
    unset AVG_NIC_SPEED
    unset AGG_NIC_SPEED
    unset NIC_COUNT
    unset DISK_COUNT
    # Get new values
    source "$f"
    cat <<EOF >> $CLUSTER_OUTPUT
[node$count]
distro = "$DISTRO"
manufacturer = "$MANUFACTURER"
product = "$PRODUCT"
memory_dims = "$MEMORY_DIMS"
memory_total = "$MEMORY_TOTAL"
core_count = "$CORE_COUNT"
cpu_mhz = "$CPU_MHZ"
nic_speeds = "$NIC_SPEEDS"
avg_nic_speed = "$AVG_NIC_SPEED"
agg_nic_speed = "$AGG_NIC_SPEED"
nic_count = "$NIC_COUNT"
disk_count = "$DISK_COUNT"

EOF
    # Analyze
    if [ "$c_node_distro" == "unknown" ] ; then
        c_node_distro="$DISTRO"
    elif [ "$c_node_distro" != "$DISTRO" ] ; then
        c_node_distro="mixed"
        homogenous=0
    fi
    if [ "$c_node_manufacturer" == "unknown" ] ; then
        c_node_manufacturer="$MANUFACTURER"
    elif [ "$c_node_manufacturer" != "$MANUFACTURER" ] ; then
        c_node_manufacturer="mixed"
        homogenous=0
    fi
    if [ "$c_node_product" == "unknown" ] ; then
        c_node_product="$PRODUCT"
    elif [ "$c_node_product" != "$PRODUCT" ] ; then
        c_node_product="mixed"
        homogenous=0
    fi
    let c_node_dims_total+=$MEMORY_DIMS
    if [ ! -n "$MEMORY_DIMS_P" ] ; then
        MEMORY_DIMS_P="$MEMORY_DIMS"
    fi
    if [ $MEMORY_DIMS_P -ne $MEMORY_DIMS ] ; then
        homogenous=0
    fi
    let c_node_memory_total+=$MEMORY_TOTAL
    if [ ! -n "$MEMORY_TOTAL_P" ] ; then
        MEMORY_TOTAL_P="$MEMORY_TOTAL"
    fi
    if [ $MEMORY_TOTAL_P -ne $MEMORY_TOTAL ] ; then
        homogenous=0
    fi
    let c_node_core_total+=$CORE_COUNT
    if [ ! -n "$CORE_COUNT_P" ] ; then
        CORE_COUNT_P="$CORE_COUNT"
    fi
    if [ $CORE_COUNT_P -ne $CORE_COUNT ] ; then
        homogenous=0
    fi
    let c_node_cpu_mhz_total+=$CPU_MHZ
    if [ ! -n "$CPU_MHZ_P" ] ; then
        CPU_MHZ_P="$CPU_MHZ"
    fi
    if [ $CPU_MHZ_P -ne $CPU_MHZ ] ; then
        homogenous=0
    fi
    let c_node_nic_avg_speed_total+=$AVG_NIC_SPEED
    if [ ! -n "$AVG_NIC_SPEED_P" ] ; then
        AVG_NIC_SPEED_P="$AVG_NIC_SPEED"
    fi
    if [ $AVG_NIC_SPEED_P -ne $AVG_NIC_SPEED ] ; then
        homogenous=0
    fi
    let c_node_nic_agg_speed_total+=$AGG_NIC_SPEED

    let c_node_nic_count_total+=$NIC_COUNT
    if [ ! -n "$NIC_COUNT_P" ] ; then
        NIC_COUNT_P="$NIC_COUNT"
    fi
    if [ $NIC_COUNT_P -ne $NIC_COUNT ] ; then
        homogenous=0
    fi
    let c_node_disk_count_total+=$DISK_COUNT
    if [ ! -n "$DISK_COUNT_P" ] ; then
        DISK_COUNT_P="$DISK_COUNT"
    fi
    if [ $DISK_COUNT_P -ne $DISK_COUNT ] ; then
        homogenous=0
    fi

    let count+=1
done
# Calculate averages
let c_node_dims_avg=$c_node_dims_total/$count
let c_node_memory_avg=$c_node_memory_total/$count
let c_node_core_avg=$c_node_core_total/$count
let c_node_cpu_mhz_avg=$c_node_cpu_mhz_total/$count
let c_node_nic_avg_speed_avg=$c_node_nic_avg_speed_total/$count
let c_node_nic_agg_speed_avg=$c_node_nic_agg_speed_total/$count
let c_node_nic_count_avg=$c_node_nic_count_total/$count
let c_node_disk_count_avg=$c_node_disk_count_total/$count

# Grab cluster information from CLI
map_capacity="`maprcli dashboard info -json |grep '\"map_task_capacity\"' |sed -e 's/[^0-9]*//g'`"
reduce_capacity="`maprcli dashboard info -json |grep '\"reduce_task_capacity\"' |sed -e 's/[^0-9]*//g'`"
nodes=$(maprcli node list -columns hostname,cpus,ttReduceSlots | awk '/^[1-9]/{if ($2>1) count++};END{print count}')
cluster_tt_nodes=$(maprcli node list -columns hostname,configuredservice -filter "[rp==/*]and[svc==tasktracker]" |tail -n +2 |wc --lines)
mapr_version=$(maprcli dashboard info -version true |tail -1 |sed -e 's/[ \t]*//g')
cluster_name=$(maprcli dashboard info -json |grep -A3 "cluster\":{" |grep "name" |sed -e 's/^.*:\"//' -e 's/\".*$//')
cluster_id=$(maprcli dashboard info -json |grep -A3 "cluster\":{" |grep "id" |sed -e 's/^.*:\"//' -e 's/\".*$//')

cd - >/dev/null 2>&1
# Complete cluster profile
cat <<EOF >> $CLUSTER_OUTPUT
[cluster]
cluster_name = "$cluster_name"
cluster_id = "$cluster_id"
mapr_version = "$mapr_version"
homogenous = "$homogenous"
cluster_nodes = "$nodes"
cluster_tt_nodes = "$cluster_tt_nodes"
distro = "$c_node_distro"
manufacturer = "$c_node_manufacturer"
product = "$c_node_product"
memory_dims_avg = "$c_node_dims_avg"
memory_total_avg = "$c_node_memory_avg"
memory_total = "$c_node_memory_total"
core_count_avg = "$c_node_core_avg"
core_count_total = "$c_node_core_total"
cpu_mhz_avg = "$c_node_cpu_mhz_avg"
nic_speed_avg = "$c_node_nic_avg_speed_avg"
agg_nic_speed_avg = "$c_node_nic_agg_speed_avg"
nic_count_avg = "$c_node_nic_count_avg"
disk_count = "$c_node_disk_count_avg"
map_slots = "$map_capacity"
reduce_slots = "$reduce_capacity"

EOF

# Run TeraTune
$TERA_SCRIPT "$TERA_LOG"

# Zip up results
cd "$OUTPUT_DIR"
tar zcf "$CLUSTER_ZIP" * >/dev/null 2>&1
# Local cleanup
# Instructions
cat <<EOF
Output file generated: $CLUSTER_ZIP
Please copy the file to your laptop in order to upload it later.
EOF
