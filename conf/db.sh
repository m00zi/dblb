# The MIT License (MIT)
# Copyright (c) 2022 Moss
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NON INFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

#!/bin/bash

clear
docker-compose down -v --remove-orphans
sleep 1
printf '\n!!! deleting databases... !!!\n\n'
rm -rf data
mkdir -p data/{w101,r201,r202,r203}
docker-compose build
docker-compose up -d --force-recreate

lbHost="lb"
replica_user="replica_user"
rootPassword="4fa288f676ef"
containerWrite101="w101"
readContainers=("r201" "r202" "r203")

until docker exec $containerWrite101 sh -c 'export MYSQL_PWD=0a43fdd132ad; mysql -u root -e ";"' &>/dev/null; do
  printf 'w101 initializing...\n'
  sleep 4
done

printf '\nmaster node successfully initialized\n\n'

for container in ${readContainers[@]}; do
  until docker-compose exec $container sh -c 'export MYSQL_PWD=0a43fdd132ad; mysql -u root -e ";"' &>/dev/null; do
    echo "$container initializing..."
    sleep 4
  done

  printf '%s => initialize replication...\n' $container

  masterStatus=$(docker exec $containerWrite101 sh -c 'export MYSQL_PWD=0a43fdd132ad; mysql -u root -e "SHOW MASTER STATUS"')
  curLog=$(echo "$masterStatus" | awk 'NR>1{print $1}')
  curPos=$(echo "$masterStatus" | awk 'NR>1{print $2}')
  slaveStmt="CHANGE MASTER TO MASTER_HOST='$containerWrite101',MASTER_USER='$replica_user',\
  MASTER_PASSWORD='$rootPassword',MASTER_LOG_FILE='$curLog',MASTER_LOG_POS=$curPos; START SLAVE;"
  bootstrap='export MYSQL_PWD=0a43fdd132ad; mysql -u root -e "'
  bootstrap+="$slaveStmt"
  bootstrap+='"'
  docker exec $container sh -c "$bootstrap" &>/dev/null
  docker exec $container sh -c "export MYSQL_PWD=0a43fdd132ad; mysql -u root -e 'SHOW SLAVE STATUS \G'" &>/dev/null
  sleep 3

done

if [[ -n $(docker ps -q -f status=running -f name=$containerWrite101) ]]; then
  printf '\n\tWriteDB is ready => host: %s\tport: %s\tusername: %s\tpassword: %s\n' 127.0.0.1 13307 root $rootPassword
  for container in ${readContainers[@]}; do
    if [[ -z $(docker ps -q -f status=running -f name=$container) ]]; then
      printf 'ReadDB node failed: host => %s\n' $container
    fi
  done
  printf '\tReadDB is ready   => host: %s\tport: %s\tusername: %s\tpassword: %s\n\n' 127.0.0.1 23306 root $rootPassword
else
  printf '\nmaster node failed\n'
fi

printf '\n\t ACCESS WRITE DATABASE => mysql -uroot -p 0a43fdd132ad -h 127.0.0.1 -P 13306\n'
printf '\t ACCESS READ DATABASE    => mysql -uroot -p 0a43fdd132ad -h 127.0.0.1 -P 23306\n\n'