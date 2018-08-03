require 'spec_helper'

describe GraphitiErrors do
  let(:klass) do
    Class.new do
      include GraphitiErrors
    end
  end

  let(:instance) { klass.new }

  it 'includes validatable' do
    expect(instance).to respond_to(:render_errors_for)
  end
end
