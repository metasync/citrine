# frozen-string-literal: true

require_relative "repository/struct"
require_relative "repository/base"

module Citrine
  module Repository
    DEFAULT_VALIDATION_INTERVAL = 15
    DEFAULT_RECONNECT_INTERVAL = 5

    def self.[](adapter)
      require_relative "repository/#{adapter}"
      "#{name}::#{adapter.to_s.classify}".constantize
    end
  end
end
