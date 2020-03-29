require 'pathname'
require 'tempfile'

require_relative './constants.rb'

module Vagrant
    module Devenv
        class Box
            attr_reader :name

            def self.add(vagrant_env, url, name)
                # Convenience method to run the box add action.
                vagrant_env.action_runner.run(Vagrant::Action.action_box_add, {
                    box_url: url,
                    box_name: name,
                    ui: vagrant_env.ui
                })
            end

            def self.remove(vagrant_env, name)
                # Convenience method to run the box remove action.
                vagrant_env.action_runner.run(Vagrant::Action.action_box_remove, {
                    box_name: name,
                    force_confirm_box_remove: true,
                    box_remove_all_versions: true,
                    ui: vagrant_env.ui
                })
            end

            def initialize(stage, checksum)
                @stage = stage
                @checksum = checksum
            end

            def name
                "#{Vagrant::Devenv::Constants::BOX_PREFIX}_#{@stage}_#{@checksum}"
            end

            def create(machine, vagrant_env)
                # Create and change directories into a temporary directory
                Dir.mktmpdir do |package_dir|
                    Dir.chdir(package_dir) do
                        # It seems like there's no way define the name of the box to create.
                        package_path = Pathname(package_dir).join("package.box")
                        machine.package(vagrant_env)
                        vagrant_env.ui.info("Creating box '#{self.name}'")
                        self.class.add(vagrant_env, package_path.to_s, self.name)
                    end
                end
            end

            def destroy(vagrant_env)
                vagrant_env.ui.info("Destroying box '#{self.name}'")
                self.class.remove(vagrant_env, self.name)
            end

            def exists?(vagrant_env)
                vagrant_env.boxes.all.each do |box|
                    if box[0] == self.name
                        return true
                    end
                end
                false
            end
        end
    end
end
