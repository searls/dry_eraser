require "rails/railtie"
require "active_support/concern"
require_relative "dry_eraser/version"

module DryEraser
  class Railtie < Rails::Railtie
    initializer "dry_eraser.initialize" do
      ActiveSupport.on_load(:active_record) do
        include DryEraser::ModelExtensions
      end
    end
  end

  module ModelExtensions
    extend ActiveSupport::Concern
    included do
      class_attribute :dry_erasers, default: []
      before_destroy :check_dry_erasers
    end

    module ClassMethods
      def dry_erase(*classes_or_instances_or_method_names)
        self.dry_erasers += classes_or_instances_or_method_names
      end
    end

    def dry_erasable?
      errors.clear

      self.class.dry_erasers.each do |dry_eraser|
        case dry_eraser
        in Class
          dry_eraser.new.dry_erase(self)
        in ->(it) { it.respond_to?(:dry_erase) }
          dry_eraser.dry_erase(self)
        in ->(it) { it.respond_to?(:call) }
          dry_eraser.call(self)
        in Symbol | String
          send(dry_eraser)
        else
          raise ArgumentError, "Invalid dry eraser: #{dry_eraser.inspect}"
        end
      end

      errors.empty?
    end

    def check_dry_erasers
      throw(:abort) unless dry_erasable?
    end
  end
end
