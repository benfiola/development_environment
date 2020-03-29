#!/bin/bash
set -e
source /vagrant/provisioning/common.sh
title="Install kubernetes"

header "$title"

echo "Virtualization support does not ensure a good kubernetes experience - skipping"

# log "Installing kubectl"

# version=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)
# url=https://storage.googleapis.com/kubernetes-release/release/$version/bin/linux/amd64/kubectl
# download_location=$(pwd)/kubectl
# install_location=/usr/local/bin/kubectl
# log "Downlading $url to $download_location"
# run_command curl --fail --silent --show-error --location --output $download_location $url
# run_command chmod +x $download_location

# log "Installing $download_location to $install_location"
# run_command sudo mv $download_location $install_location

# log "Installing virtualbox"
# gpg_url=https://www.virtualbox.org/download/oracle_vbox_2016.asc
# repository="deb [arch=amd64] https://download.virtualbox.org/virtualbox/debian $(lsb_release -cs) contrib"
# log "Adding repository ($repository) with gpg url ($gpg_url)"
# key_file=$(mktemp --suffix .gpg)
# run_command curl --fail --silent --show-error $gpg_url --output $key_file
# run_command cat $key_file | sudo apt-key add -
# run_command rm -rf $key_file
# run_command "sudo add-apt-repository '$repository'"
# run_command sudo apt-get install -y virtualbox-6.1


# log "Installing minikube"
# url=https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
# download_location=$(pwd)/minikube
# install_location=/usr/local/bin/minikube
# log "Downlading $url to $download_location"
# run_command curl --fail --silent --show-error --location --output $download_location $url
# run_command chmod +x $download_location

# log "Installing $download_location to $install_location"
# run_command sudo mv $download_location $install_location

footer "$title"
