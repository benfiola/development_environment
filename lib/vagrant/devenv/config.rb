require "dry-validation"

require_relative './errors.rb'

module Vagrant
    module Devenv
        module Configuration
            module InitializerMixin
                def default(key, value)
                    # convenience method to express default values
                    option key, :default => proc { value }
                end

                def as_hash(obj)
                    # convenience method to consume incoming data and return an initialized hash
                    obj = self.new(**obj)
                    self.dry_initializer.attributes(obj)
                end
            end

            class Initializer
                extend Dry::Initializer
                extend InitializerMixin

                default :base_box, "bento/ubuntu-18.04"
                default :cpus, 8
                default :desktop, "xfce4"
                default :disk, 20000
                default :memory, 8192
                default :shell, "zsh"
                default :tool_clion, true
                default :tool_cplusplus, true
                default :tool_docker, true
                default :tool_git, true
                default :tool_google_chrome, true
                default :tool_kubernetes, true
                default :tool_mdns, true
                default :tool_nodenv, true
                default :tool_pycharm, true
                default :tool_pyenv, true
                default :tool_qemu, true
                default :tool_spotify, true
                default :tool_unity, true
                default :username, "default"
                default :version, "1.0.0"
            end

            class Contract < Dry::Validation::Contract
                params do
                    required(:base_box).filled(:string)
                    required(:cpus).filled(:integer)
                    required(:desktop).filled(:string)
                    required(:disk).filled(:integer)
                    required(:memory).filled(:integer)
                    required(:name).filled(:string)
                    required(:shell).filled(:string)
                    required(:tool_clion).value(:bool)
                    required(:tool_cplusplus).value(:bool)
                    required(:tool_docker).value(:bool)
                    required(:tool_git).value(:bool)
                    required(:tool_google_chrome).value(:bool)
                    required(:tool_kubernetes).value(:bool)
                    required(:tool_mdns).value(:bool)
                    required(:tool_nodenv).value(:bool)
                    required(:tool_pycharm).value(:bool)
                    required(:tool_pyenv).value(:bool)
                    required(:tool_qemu).value(:bool)
                    required(:tool_spotify).value(:bool)
                    required(:tool_unity).value(:bool)
                    required(:username).filled(:string)
                    required(:version).filled(:string)
                end
            end

            def self.new(data)
                initialized_data = Initializer.as_hash(**data)
                initialized_data.merge!(data) { |_, v1, _| v1}
                validated_data = Contract.new.call(initialized_data)
                raise Vagrant::Devenv::ValidationError, validated_data.errors.to_h unless validated_data.errors.empty?
                validated_data.values.data
            end
        end
    end
end