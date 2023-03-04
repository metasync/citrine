# frozen_string_literal: true

require "sequel"

# Enable inflection instance methods to String
Sequel.extension :inflector

require "celluloid/current"
require_relative "citrine/celluloid_ext"
require_relative "citrine/version"
require_relative "citrine/error"
require_relative "citrine/utils"
require_relative "citrine/configuration"
require_relative "citrine/schema"
require_relative "citrine/operation"
require_relative "citrine/actor"
require_relative "citrine/interactor"
require_relative "citrine/repository"
require_relative "citrine/warden"
require_relative "citrine/integrator"
require_relative "citrine/gateway"
require_relative "citrine/runner"
require_relative "citrine/configurator/autoloader"
require_relative "citrine/manager"
require_relative "citrine/cli"
