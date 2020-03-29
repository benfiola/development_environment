

module Vagrant
    module Devenv
        def self.prefixed_ui(name)
            # This is a factory for Vagrant::UI::Prefixed subclasses (to allow for custom prefixes)
            # It seems like Vagrant::Environment expects a ui_class, which makes constructing something
            # that requires an instance arg (the prefix itself) hard without scattering around subclasses
            # in the project.
            cls = Class.new(Vagrant::UI::Prefixed) do
                @@prefix = nil

                def self.prefix
                    @@prefix
                end

                def self.prefix=(value)
                    @@prefix = value
                end

                def initialize
                    super(Vagrant::UI::Basic.new, self.class.prefix)
                end
            end
            cls.prefix = name
            return cls
        end
    end
end
