class ContentParseError < StandardError
  attr_reader :reason

  def initialize(reason)
    @reason = reason
  end
end

class ContentFetchError < StandardError
  attr_reader :response

  def initialize(response)
    @response = response
  end
end
