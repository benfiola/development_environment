require 'thor'

require_relative './cli.rb'


module Vagrant
    module Devenv
        class Command < Vagrant.plugin("2", :command)
            class CLI < Thor
                class Devenv < Vagrant::Devenv::CLI::Main
                end

                desc "devenv SUBCOMMAND", "coerces CLI to match vagrant plugin usage", :hide => true
                subcommand "devenv", Devenv
            end

            def execute
                args = [*ARGV]
                args.push(*["--vagrant_home_path", @env.home_path.to_s])
                CLI.start args
            end

            def self.synopsis
                "commands to help bootstrap development VMs (plugin: vagrant-devenv)"
            end
        end
    end
end