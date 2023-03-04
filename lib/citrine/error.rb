# frozen-string-literal: true

module Citrine
  class Error < StandardError; end

  class InternalServerError < Error
    def initialize
      super("Internal Server Error! " \
            "The server was unable to complete your request. " \
            "We apologize for the inconvenience and appreicate your patience.")
    end
  end
end
