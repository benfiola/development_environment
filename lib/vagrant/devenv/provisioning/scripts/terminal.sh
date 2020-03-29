#!/bin/bash
set -e
source /vagrant/provisioning/common.sh
title="Set up terminal"
user=$1

header "$title"

log "Installing zsh"
run_command sudo apt-get install -y zsh

shell_path=/usr/bin/zsh
log "Setting default shell to $shell_path for $user"
run_command sudo usermod --shell $shell_path $user

log "Installing terminator"
run_command sudo apt-get install -y terminator

sudo -i -u $user /bin/bash <<-EOF
    set -e
    source /vagrant/provisioning/common.sh

    log "Installing terminator configuration (as $user)"
    mkdir -p ~/.config/terminator
    cp /vagrant/resources/terminator.config ~/.config/terminator/config
EOF

sudo -i -u $user /bin/bash <<-EOF
    set -e
    source /vagrant/provisioning/common.sh

    log "Installing oh-my-zsh (as $user)"

    script_file=\$(mktemp --suffix .sh)
    script_url="https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
    log "Downloading install script (\$script_url) to \$script_file (as $user)"
    run_command curl --fail --silent --show-error --location --output \$script_file \$script_url

    log "Running install script (\$script_file) (as $user)"
    run_command bash \$script_file

    log "Cleaning up (as $user)"
    run_command rm \$script_file

    log "Installing oh-my-zsh theme (as $user)"
    run_command cp /vagrant/resources/theme.zsh-theme ~/.oh-my-zsh/themes/theme.zsh-theme

    log "Installing .zshrc (as $user)"
    run_command cp /vagrant/resources/.zshrc ~/.zshrc 
EOF

footer "$title"
