#!/usr/bin/env bash
#
# Merge logstash format indices from elasticsearch maintaining only a
# specified number.
#
#   Inspiration:
#     https://github.com/imperialwicket/elasticsearch-logstash-index-mgmt/blob/master/elasticsearch-remove-old-indices.sh
#
# Must have access to the specified elasticsearch node.

usage()
{
cat << EOF

elasticsearch-formerge-indices.sh

Merge all indices older than a date.


USAGE: ./elasticsearch-formerge-indices.sh [OPTIONS]

OPTIONS:
  -h    Show this message
  -d    Expiration date (YYYY-MM-dd) from when we should start deleting the indices (default: 1 days ago)
  -e    Elasticsearch URL (default: http://localhost:9200)
  -g    Consistent index name (default: logstash)
  -o    Output actions to a specified file

EXAMPLES:

  ./elasticsearch-formerge-indices.sh

    Connect to http://localhost:9200 and get a list of indices matching
    'logstash'. Keep the indices from less than 3 months, delete any others.

  ./elasticsearch-formerge-indices.sh -e "http://es.example.com:9200" \
  -d 1991-04-25 -g my-logs -o /mnt/es/logfile.log

    Connect to http://es.example.com:9200 and get a list of indices matching
    'my-logs'. Keep the indices created after the 25 april 1991, merge any others.
    Output index merges to /mnt/es/logfile.log.

EOF
}

# Defaults
ELASTICSEARCH="http://localhost:9200"
DATE=$(date  --date="1 days ago" +"%Y%m%d")
INDEX_NAME="logstash"
LOGFILE=/dev/null

# Validate numeric values
RE_DATE="^[0-9]{4}-((0[0-9])|(1[0-2]))-(([0-2][0-9])|(3[0-1]))+$"

while getopts ":d:e:g:o:h" flag
do
  case "$flag" in
    h)
      usage
      exit 0
      ;;
    d)
      if [[ $OPTARG =~ $RE_DATE ]]; then
        DATE=$OPTARG
      else
        ERROR="${ERROR}Expiration date must be YYYY-MM-dd.\n"
      fi
      ;;
    e)
      ELASTICSEARCH=$OPTARG
      ;;
    g)
      INDEX_NAME=$OPTARG
      ;;
    o)
      LOGFILE=$OPTARG
      ;;
    ?)
      usage
      exit 1
      ;;
  esac
done

# If we have errors, show the errors with usage data and exit.
if [ -n "$ERROR" ]; then
  echo -e $ERROR
  usage
  exit 1
fi

# If we are logging, make sure we have a logfile TODO - handle errors here
if [ -n "$LOGFILE" ] && ! [ -e $LOGFILE ]; then
  touch $LOGFILE
fi

# Merge indices
INDEX_DATE=$(date -d $DATE +"%Y.%m.%d")
INDEX="$ELASTICSEARCH/$INDEX_NAME$INDEX_DATE/_forcemerge?max_num_segments=1"
echo START `date '+%F %X'` curl -s -XPOST "$INDEX" >> $LOGFILE 2>&1
curl -s -XPOST "$INDEX" >> $LOGFILE 2>&1
echo -e "\n" END `date '+%F %X'` curl -s -XPOST "$INDEX" >> $LOGFILE 2>&1
exit 0
