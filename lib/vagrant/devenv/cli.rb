require 'thor'

require_relative './config.rb'
require_relative './development_environment.rb'


module Vagrant
    module Devenv
        module CLI
            class Main < Thor
                class_option :vagrant_home_path, :hide => true, :type => :string, :required => true

                desc "clean", "Clean unused byproducts of vagrant devenv"
                def clean
                    Vagrant::Devenv::DevelopmentEnvironment.clean(self.vagrant_home_path)
                end

                desc "create <name>", "Create a devenv"
                def create(name)
                    configuration = Vagrant::Devenv::Configuration.new({:name => name})
                    environment = Vagrant::Devenv::DevelopmentEnvironment.new(configuration[:name], self.vagrant_home_path)
                    environment.create(configuration)
                end

                desc "destroy <name>", "Destroy a devenv"
                def destroy(name)
                    environment = Vagrant::Devenv::DevelopmentEnvironment.new(name, self.vagrant_home_path)
                    environment.destroy
                end

                desc "list", "List devenvs"
                def list
                    Vagrant::Devenv::DevelopmentEnvironment.list(self.vagrant_home_path)
                end

                no_commands do
                    def vagrant_home_path
                        self.options["vagrant_home_path"]
                    end
                end
            end
        end
    end
end