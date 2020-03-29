#!/bin/bash
set -e
source /vagrant/provisioning/common.sh
title="Create user"
user=$1

header "$title"

log "Creating admin group (in case it doesn't exist)"
run_command sudo groupadd --force admin

log "Creating user $user with password $password"
password=$(perl -e "print crypt('$user', '$user')")
run_command sudo useradd --password $password --create-home $user --groups admin,sudo,vboxsf,staff

footer "$title"
