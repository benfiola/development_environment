require 'pathname'
require 'yaml'

require_relative './box.rb'
require_relative './constants.rb'
require_relative './errors.rb'
require_relative './machine.rb'
require_relative './ui.rb'

module Vagrant
    module Devenv
        class DevelopmentEnvironment
            def self.all(home_path)
                # Finds all development environments within the given home_path
                subfolders = self.path_devenv_folder(home_path).children.select { |c| c.directory? }
                to_return = []
                subfolders.each do |subfolder|
                    environment = self.new(subfolder.basename.to_s, home_path)
                    if environment.exists?
                        to_return << environment
                    end
                end
                to_return
            end

            def self.clean(home_path)
                global_env = self.vagrant_env(home_path)

                global_env.ui.info("Cleaning unused vagrant-devenv files")

                # find boxes in use
                boxes_in_use = Set.new
                self.all(home_path).each do |environment|
                    environment.machines.each do |machine|
                        boxes_in_use.add machine.box.name
                    end
                end

                # iterate on global box collection, removing boxes that have the devenv prefix
                # but aren't in use by an active environment.
                boxes_to_remove = Set.new
                global_env.boxes.all.each do |box|
                    box_name = box[0]
                    if boxes_in_use.include? box_name
                        next
                    end
                    unless box_name.start_with? Vagrant::Devenv::Constants::BOX_PREFIX
                        next
                    end
                    boxes_to_remove.add box
                end

                # remove all found boxes
                boxes_to_remove.each do |box|
                    box_name = box[0]
                    global_env.ui.info("Removing box '#{box_name}'")
                    Vagrant::Devenv::Box.remove(global_env, box_name)
                end

                global_env.ui.success("Cleaned unused vagrant-devenv files")
            end

            def self.list(home_path)
                env = self.vagrant_env(home_path)
                self.all(home_path).each do |devenv|
                    env.ui.info(devenv.name)
                end
            end

            def self.vagrant_env(home_path, cwd=nil)
                # Generates a 'global' vagrant environment - one whose cwd doesn't contain a Vagrantfile
                # This is primarily for consistent logging, even when a vagrant-devenv hasn't been created yet.
                opts = {
                    home_path: home_path,
                    local_data_path: home_path,
                    ui_class: Vagrant::Devenv.prefixed_ui("vagrant-devenv"),
                    cwd: cwd
                }
                Vagrant::Environment.new(opts)
            end

            def self.path_devenv_folder(home_path)
                Pathname(home_path).join("devenv")
            end

            attr_reader :name
            def initialize(name, home_path)
                @name = name
                @home_path = home_path
                @machines = nil
                @config = nil
                @local_vagrant_env = nil
                @global_vagrant_env = self.class.vagrant_env(home_path)
            end

            def config
                # If the devenv doesn't exist, there won't be any files to parse.
                unless self.exists?
                    raise Vagrant::Devenv::EnvironmentDoesNotExist, @name
                end

                if @config == nil
                    config = YAML.load_file(self.path_config.to_s)
                    config = Vagrant::Devenv::Configuration.new(config)
                    @config = config
                end
                @config
            end

            def create(config)
                # If the devenv already exists, require the user to destroy it first.
                if self.exists?
                    raise Vagrant::Devenv::EnvironmentExists, @name
                end

                @global_vagrant_env.ui.info("Creating development environment '#{@name}'")

                @global_vagrant_env.ui.info("Creating environment workspace '#{self.path_folder}'")
                self.path_folder.mkpath
                self.path_vagrantfile.write Vagrant::Devenv::Vagrantfile.content
                self.path_config.write YAML.dump(config)

                begin
                    machine = self.machines[0]

                    while machine != nil
                        if machine.next != nil
                            # create a machine, and then a box if this isn't the final machine
                            unless machine.box.exists?(self.vagrant_env)
                                unless machine.exists?(self.vagrant_env)
                                    # create the machine if it doesn't exist
                                    machine.create(self.vagrant_env)
                                end
                                # create the box if it doesn't exist
                                machine.box.create(machine, self.vagrant_env)
                                # destroy the machine once the box is created
                                machine.destroy(self.vagrant_env)
                            end
                        else
                            # create the machine if this is the final machine
                            machine.create(self.vagrant_env)
                        end
                        machine = machine.next
                    end

                    self.vagrant_env.ui.success("Created environment '#{@name}'")
                rescue Exception => e
                    @global_vagrant_env.ui.error("Failed to create environment '#{@name}' - cleaning up")
                    begin
                        self.destroy
                    rescue Exception => e2
                        @global_vagrant_env.ui.error("Clean up failed - #{e2.to_s}")
                    end
                    raise e
                end
            end

            def destroy
                # Destroying a non-existent devenv is futile.
                unless self.exists?
                    raise Vagrant::Devenv::EnvironmentDoesNotExist, @name
                end

                # Destroy environment's machines first (once the Vagrantfile is removed these machines are orphaned)
                self.vagrant_env.ui.info("Destroying environment '#{@name}'")
                machine = self.machines[0]
                while machine != nil
                    if machine.exists?(self.vagrant_env)
                        machine.destroy(self.vagrant_env)
                    end
                    machine = machine.next
                end

                # Remove the environment workspace
                self.vagrant_env.ui.info("Deleting environment workspace '#{self.path_folder.to_s}'")
                self.path_folder.rmtree

                @global_vagrant_env.ui.success("Destroyed environment '#{@name}'")
            end

            def exists?
                # A devenv only exists if all required files exists.
                (Dir.exists? self.path_folder) && (File.exists? self.path_config) && (File.exists? self.path_vagrantfile)
            end

            def machines
                if @machines == nil
                    @machines = [
                        Vagrant::Devenv::Machine.new("base", self.config),
                        Vagrant::Devenv::Machine.new("environments", self.config),
                        Vagrant::Devenv::Machine.new("tools", self.config),
                        Vagrant::Devenv::Machine.new("personalization", self.config),
                        Vagrant::Devenv::Machine.new("final", self.config)
                    ]
                    @machines.each_with_index do |current, index|
                        unless index == 0
                            current.previous = machines[index - 1]
                            current.previous.next = current
                        end
                    end
                end
                @machines
            end


            def path_config
                self.path_folder.join("devenv.yml")
            end

            def path_folder
                self.class.path_devenv_folder(@home_path).join(@name)
            end

            def path_vagrantfile
                self.path_folder.join("Vagrantfile")
            end

            def vagrant_env
                # Creates a local vagrant environment (one that contains a Vagrantfile)
                # As a result, if this isn't devenv, this should fail.
                unless self.exists?
                    raise Vagrant::Devenv::EnvironmentDoesNotExist, @name
                end

                if @local_vagrant_env == nil
                    @local_vagrant_env = self.class.vagrant_env(@home_path, self.path_folder.to_s)
                end
                @local_vagrant_env
            end
        end
    end
end
