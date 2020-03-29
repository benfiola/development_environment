=begin

=end
require "pathname"
require "yaml"

require_relative "./config.rb"
require_relative './machine.rb'

module Vagrant
    module Devenv
        module Vagrantfile
            def self.content
                # Data emitted into a devenv's environment workspace
                return <<~END
                    require 'pathname'
                    vagrantfile_path = (Pathname(__FILE__).realpath.to_s)
                    Vagrant::Devenv::Vagrantfile.entrypoint(vagrantfile_path)
                END
            end

            def self.entrypoint(vagrantfile_path)
                # Method called from a devenv's Vagrantfile.
                # Code called from within here runs the risk of infinite looping if there's any attempt
                # to access a 'local vagrant environment' since creating a local environment runs this code.

                # derive development environment from Vagrantfile path.
                vagrantfile_path = Pathname(vagrantfile_path)
                env_name = vagrantfile_path.parent.basename
                home_path = vagrantfile_path.parent.parent.parent.to_s
                environment = Vagrant::Devenv::DevelopmentEnvironment.new(env_name, home_path)

                # configure vagrant machines
                Vagrant.configure("2") do |vagrant|
                    environment.machines.each do |machine|
                        machine.define(vagrant)
                    end
                end
            end
        end
    end
end