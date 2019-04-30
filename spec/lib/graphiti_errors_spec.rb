require "spec_helper"

describe GraphitiErrors do
  let(:klass) do
    Class.new do
      include GraphitiErrors
    end
  end

  let(:instance) { klass.new }
end
