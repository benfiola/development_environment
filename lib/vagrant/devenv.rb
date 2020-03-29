require 'vagrant'


module Vagrant
    module Devenv
        class Plugin < Vagrant.plugin('2')
            name "vagrant-devenv"

            description <<-DESC
                Vagrant plugin that will bootstrap development environment VMs.
            DESC

            command('devenv') do
                require_relative "./devenv/command"
                require_relative "./devenv/vagrantfile"
                Command
            end
        end
    end
end
