require 'digest/md5'
require 'pathname'
require 'yaml'

require 'mustache'

require_relative './box.rb'
require_relative './constants.rb'

module Vagrant
    module Devenv
        class Machine
            attr_accessor :previous, :next
            attr_reader :box

            def self.up(vagrant_machine)
                # Convenience method to run vagrant up on a given machine
                # Vagrant needs to be able to instantiate an internal machine to perform operations on them.
                # This is why a vagrant_machine is an argument here.
                vagrant_machine.action(:up)
            end

            def self.destroy(vagrant_machine)
                # Convenience method to run vagrant destroy on the given machine
                # Vagrant needs to be able to instantiate an internal machine to perform operations on them.
                # This is why a vagrant_machine is an argument here.
                vagrant_machine.action(:destroy, {
                    :force_confirm_destroy => true
                })
            end

            def self.package(vagrant_machine, name)
                # Convenience method to run vagrant package on the given machine
                # It's assumed that this is being run within the directory where the package should be made.
                # Vagrant needs to be able to instantiate an internal machine to perform operations on them.
                # This is why a vagrant_machine is an argument here.
                vagrant_machine.action(:package, {
                    name: name
                })
            end

            def initialize(stage, config)
                @stage = stage
                @config = config

                @previous = nil
                @next = nil

                @checksum = nil
                @vagrant_env = nil

                @provisioning_base_path = Pathname(__dir__).join("provisioning")
                @provisioning_mount_point = Pathname("/provisioning")
                @provisioning_playbook = @provisioning_base_path.join(@stage).join("stage.yml")
                @provisioning_playbook_mount = @provisioning_mount_point.join(@provisioning_playbook.relative_path_from(@provisioning_base_path))
            end

            def box
                Vagrant::Devenv::Box.new(@stage, self.checksum)
            end

            def name
                return "#{Vagrant::Devenv::Constants::MACHINE_PREFIX}_#{@stage}_#{self.checksum}" unless @next == nil
                @config[:name]
            end

            def checksum
                if @checksum == nil
                    # set @checksum to a pending value to break an infinite loop
                    @checksum = "pending"

                    # Calculates a checksum for the current machine
                    # Swap the current configuration for a proxy
                    config = @config
                    proxy = ConfigProxy.new(config)
                    @config = proxy

                    # Evaluate vagrantfile
                    self.define(VagrantConfigureProxy.new)

                    unless @next == nil
                        # check ansible playbooks for non-final machines
                        self.ansible_config_accesses(@provisioning_playbook)
                    end

                    # Swap configuration back to normal Hash
                    @config = config

                    # Collect dependent configuration values
                    used_config = {}
                    proxy.accessed.each do |key|
                        used_config[key] = @config[key]
                    end

                    # Calculate the hash for used configuration values and the checksum for the previous VM
                    # (if the previous VM changes, this should too).
                    to_return = {}
                    to_return["current"] = used_config
                    to_return["previous"] = @previous.checksum unless @previous == nil
                    @checksum = Digest::MD5.hexdigest(Marshal.dump(to_return))
                end
                @checksum
            end

            def create(vagrant_env)
                vagrant_env.ui.info("Creating machine '#{self.name}'")
                self.vagrant_machine(vagrant_env) do |machine|
                    self.class.up(machine)
                end
            end

            def destroy(vagrant_env)
                vagrant_env.ui.info("Destroying machine '#{self.name}'")
                self.vagrant_machine(vagrant_env) do |machine|
                    self.class.destroy(machine)
                end
            end

            def exists?(vagrant_env)
                self.vagrant_machine(vagrant_env) do |machine|
                    machine.state.id != :not_created
                end
            end

            def package(vagrant_env)
                vagrant_env.ui.info("Packaging machine '#{self.name}'")
                self.vagrant_machine(vagrant_env) do |machine|
                    self.class.package(vagrant_env, self.name)
                end
            end

            def vagrant_machine(vagrant_env, &block)
                base_machine = vagrant_env.machine(self.name.to_sym, vagrant_env.default_provider.to_sym)
                base_machine.with_ui(vagrant_env.ui) do
                    block.call(base_machine)
                end
            end

            def ansible_config_accesses(file)
                # leverage mustache templates and a config proxy to detect
                # which elements of configuration depend on the machine's playbook.
                file = Pathname(file)
                text = Mustache.render(file.read, @config)
                data = YAML.load(text)

                # collect data from the current ansible file
                referenced_playbooks = Set.new
                referenced_tasks = Set.new
                when_conditionals = Set.new

                # playbooks/task lists are lists.  data should respond to each.
                if data.respond_to?("each")
                    data.each do |obj|
                        # playbook imports
                        pb_keys = %w(import_playbook include_playbook)
                        pb_keys.each do |pb_key|
                            if obj.include? pb_key
                                referenced_playbooks << obj[pb_key]
                            end
                        end

                        if obj.include? "tasks"
                            obj["tasks"].each do |task|
                                task_keys = %w(import_tasks include_tasks)
                                task_keys.each do |task_key|
                                    if task.include? task_key
                                        referenced_tasks << task[task_key]
                                    end
                                end
                                # conditionals are mustache templates without {{ }}
                                when_keys = %w(when)
                                when_keys.each do |when_key|
                                    if task.include? when_key
                                        when_conditionals << task[when_key]
                                    end
                                end
                            end
                        end
                    end
                end

                # process collected data
                # playbooks and tasks yield a recursive call into this function
                referenced_playbooks.merge(referenced_tasks).each do |referenced_file|
                    referenced_file = file.parent.join(referenced_file)
                    self.ansible_config_accesses(referenced_file.realpath.to_s)
                end
                # when conditionals are wrapped with mustaches and evaluated
                when_conditionals.each do |when_conditional|
                    Mustache.render("{{ #{when_conditional} }}", @config)
                end
            end

            def define(vagrant)
                vagrant.vm.define self.name do |vm|
                    if @previous == nil
                        # use the base box defined in configuration for the first machine
                        vm.vm.box = @config[:base_box]
                    else
                        # use the previous machines' name as a box
                        vm.vm.box = @previous.box.name
                    end

                    if @next == nil
                        # define a fully featured VM since this is the final VM in the chain.
                        vm.vm.provider :virtualbox do |vb|
                            vb.memory = @config[:memory]
                            vb.cpus = @config[:cpus]
                            vb.name = self.name
                            vb.customize ['modifyvm', :id, '--clipboard-mode', 'bidirectional']
                            vb.customize ["modifyvm", :id, "--draganddrop", "bidirectional"]
                            vb.customize ["modifyvm", :id, "--vram", "256"]
                            vb.customize ["modifyvm", :id, "--graphicscontroller", "vmsvga"]
                            vb.customize ["modifyvm", :id, "--accelerate3d", "on"]
                            vb.customize ["modifyvm", :id, "--audio", "dsound"]
                            vb.customize ["modifyvm", :id, "--audioout", "on"]
                            vb.customize ["modifyvm", :id, "--usbxhci", "on"]
                            vb.customize ["modifyvm", :id, "--nested-hw-virt", "on"]
                        end
                        vm.ssh.insert_key = true
                        vm.disksize.size = "#{@config[:disk]}MB"
                    else
                        # define an intermediary VM from which a box will be generated.
                        vm.vm.provider :virtualbox do |vb|
                            vb.memory = 512
                            vb.cpus = 2
                            vb.name = self.name
                        end
                        vm.ssh.insert_key = false
                        vm.vm.synced_folder @provisioning_base_path.to_s, @provisioning_mount_point.to_s
                        vm.vm.provision "ansible_local" do |ansible|
                            ansible.playbook = @provisioning_playbook_mount.to_s
                            ansible.extra_vars = @config
                        end
                    end
                end
            end
        end

        class ConfigProxy < Hash
            # A hash proxy (and subclass, unfortunately) that detects when members are accessed.
            # This object is used to determine which configuration values are pertinent for each machine.
            attr_reader :accessed
            def initialize(config)
                self.update(config)
                @config = config
                @accessed = Set.new
            end

            def [](key)
                @accessed.add(key)
                @config[key]
            end

            def has_key?(key)
                @config.has_key?(key)
            end

            def fetch(key, default)
                return self[key] if self.has_key?(key)
                default
            end

            def to_hash
                self
            end
        end

        class VagrantConfigureProxy
            # Since Vagrant configurations are lazily loaded, this proxy
            # evaluates the entire vagrant configuration because it reflects
            # itself on member access.  This is used in conjunction with
            # a ConfigProxy to determine when configuration members are accessed
            # within a vagrantfile.
            def method_missing(*args, **kwargs)
                if block_given?
                    yield self
                else
                    self
                end
            end
        end
    end
end