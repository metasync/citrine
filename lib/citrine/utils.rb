# frozen-string-literal: true

require_relative "utils/core_refinements"
require_relative "utils/base_object"
require_relative "utils/configuration"
require_relative "utils/namespace"
require_relative "utils/common"
require_relative "utils/deep_sort"
require_relative "utils/signer"

module Citrine
  module Utils
    def self.deep_clone(obj)
      Marshal.load(Marshal.dump(obj))
    end
  end
end
