#!/bin/bash
set -e
source /vagrant/provisioning/common.sh
desktop_environment=$1
user=$2

title="Personalize $desktop_environment desktop environment"
header "$title"

if [[ "$desktop_environment" == "xfce4" ]]; then
    log "Installing theme"
    run_command sudo apt-get install -y materia-gtk-theme

    log "Installing fonts"
    run_command sudo apt-get install -y fonts-roboto
    run_command sudo apt-get install -y fonts-firacode

sudo -i -u $user /bin/bash <<-EOF
    set -e
    source /vagrant/provisioning/common.sh

    log "Setting theme (as $user)"
    run_command 'dbus-run-session -- xfconf-query -c xsettings -p /Net/ThemeName -s "Materia-dark"'

    log "Setting fonts (as $user)"
    run_command 'dbus-run-session -- xfconf-query -c xsettings -p /Gtk/FontName -s "Roboto Medium 10"'
    run_command 'dbus-run-session -- xfconf-query -c xsettings -p /Gtk/MonospaceFontName -s "FiraCode Medium 10"'
EOF

elif [[ "$desktop_environment" == "kdeplasma" ]]; then
    log "Installing xvfb (needed to run lookandfeeltool)"
    run_command sudo apt-get install -y xvfb

    log "Installing fonts"
    run_command sudo apt-get install -y fonts-roboto
    run_command sudo apt-get install -y fonts-firacode

sudo -i -u $user /bin/bash <<-EOF
    set -e
    source /vagrant/provisioning/common.sh

    log "Setting theme (as $user)"
    run_command "xvfb-run lookandfeeltool -a 'org.kde.breezedark.desktop'"
EOF

elif [[ "$desktop_environment" == "budgie" ]]; then
    log "Installing theme"
    run_command sudo apt-get install -y materia-gtk-theme

    log "Installing fonts"
    run_command sudo apt-get install -y fonts-roboto
    run_command sudo apt-get install -y fonts-firacode

sudo -i -u $user /bin/bash <<-EOF
    set -e
    source /vagrant/provisioning/common.sh

    log "Setting theme (as $user)"
    run_command 'gsettings set org.gnome.desktop.interface gtk-theme "Materia-dark"'
EOF

fi

footer "$title"
