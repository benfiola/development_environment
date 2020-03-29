require "vagrant"

module Vagrant
    module Devenv
        class Error < Vagrant::Errors::VagrantError
        end

        class EnvironmentDoesNotExist < Error
            def initialize(name)
                @name = name
            end

            def message
                "Environment '#{@name}' does not exist"
            end
        end

        class EnvironmentExists < Error
            def initialize(name)
                @name = name
            end

            def message
                "Environment '#{@name}' exists"
            end
        end

        class ValidationError < Error
            def initialize(validation_errors)
                @validation_errors = validation_errors
            end

            def message
                messages = ["Invalid configuration detected with the following errors:"]
                @validation_errors.keys.each do |key|
                    value = @validation_errors[key]
                    messages << " #{key.to_s} #{value.to_s}"
                end
                messages.join("\n")
            end
        end
    end
end