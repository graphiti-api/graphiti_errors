$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

require "graphiti_spec_helpers"
require "rails"
require "pry"
require "pry-byebug"

require "graphiti_errors"

require File.expand_path("../support/basic_rails_app.rb", __FILE__)
require "action_controller/railtie"
require "rspec/rails"
Rails.application = BasicRailsApp.generate

RSpec.configure do |config|
  config.include GraphitiSpecHelpers
end
