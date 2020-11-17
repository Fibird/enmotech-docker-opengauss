#!/bin/bash

BASEDIR=$(dirname $0)
. ${BASEDIR}/config

# Usage info
show_help() {
cat << EOF
Usage: ${0##*/} -n cluster-name 
Create a serverless opengauss cluster.
      -h, --help		display help and exit
      -n, --name		set name of opengauss cluster
EOF
}

getopt --test > /dev/null
if [[ $? -ne 4 ]]
then
  echo "Error:`getopt --test` failed in this environment."
  exit 1
fi

# Options of this tool
SHORT=n:h
LONG=name:,help

# Use getopt tool to parse options from users
PARSED=$(getopt --options $SHORT --longoptions $LONG --name "$0" -- "$@")
if [[ $? -ne 0 ]]
then
  show_help
  exit 2
fi

eval set -- "$PARSED"

while true; do
  case "$1" in
    -h|--help)
      shift
      ;;
    -n|--name)
      name="$2"
      shift 2
      ;;
    --)       # End of all options
      shift
      break
      ;;
    *)
      exit 3
      ;;
  esac
done

if [[ -z "$name" ]]; then
    echo "name of cluster cannot be null!"
    show_help
    exit -1
fi

slave_count=$(docker run -it --network serverless_network --rm mysql mysql -h $DB_SERVER_NAME -uroot -p$DB_PWD -D serverless_db -e "select slave_count from metadata where cluster_name = '$name';" | grep -E "[0-9]+" | awk '{print $2}')
hosts="$name"_master

for ((i=1;i<=slave_count;i++)); do
    hosts="$hosts "$name"_slave$i"
done

docker stats $hosts

