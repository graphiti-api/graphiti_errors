require "spec_helper"

class CustomStatusError < StandardError; end
class CustomTitleError < StandardError; end
class MessageTrueError < StandardError; end
class MessageProcError < StandardError; end
class MetaProcError < StandardError; end
class LogFalseError < StandardError; end
class CustomHandlerError < StandardError; end
class SpecialPostError < StandardError; end

module Graphiti::Errors
  class BadRequest < StandardError
    attr_reader :errors

    def initialize(errors)
      @errors = errors
    end
  end
end

class CustomErrorHandler < GraphitiErrors::ExceptionHandler
  def status_code(e)
    302
  end
end

class ApplicationController < ActionController::Base
  include GraphitiErrors

  rescue_from Exception do |e|
    handle_exception(e, show_raw_error: show_raw_error?)
  end

  def show_raw_error?
    false
  end
end

class PostsController < ApplicationController
  def index
    render json: {}
  end

  def update
    head(:no_content)
  end
end

class SpecialPostsController < PostsController
  def index
    GraphitiErrors.enable!
    raise SpecialPostError
  end
end

RSpec.describe "graphiti_errorable", type: :controller do
  controller(PostsController) { }

  def raises(klass, message, action: :index)
    expect(controller).to receive(action).and_raise(klass, message)
  end

  def error
    json["errors"][0]
  end

  def standard_detail
    "We've notified our engineers and hope to address this issue shortly."
  end

  context "when a random error thrown" do
    before do
      raises(StandardError, "some_error")
    end

    it "gives stock jsonapi-compatible error response" do
      expect(Rails.logger).to receive(:error).twice
      get :index

      expect(response.status).to eq(500)
      expect(json).to eq({
        "errors" => [
          "code" => "internal_server_error",
          "status" => "500",
          "title" => "Error",
          "detail" => standard_detail,
          "meta" => {},
        ],
      })
    end

    context "and show_raw_error is true" do
      before do
        allow(controller).to receive(:show_raw_error?) { true }
      end

      it "renders the raw error in meta" do
        get :index

        meta = json["errors"][0]["meta"]
        expect(meta).to have_key("__raw_error__")
        raw = meta["__raw_error__"]
        expect(raw["message"]).to eq("some_error")
        backtrace = raw["backtrace"]
        expect(backtrace.length).to be > 0
        expect(backtrace).to be_kind_of(Array)
      end
    end
  end

  if defined?(Graphiti::Errors::ConflictRequest)
    context "when a graphiti conflict request error" do
      let(:errors_object) do
        double(:errors, {
                 details: {
                 },
                 messages: {
                 }
               }
              )
      end
      before do
        raises(Graphiti::Errors::ConflictRequest, errors_object, action: :update)
      end

      it "returns a conflict request error" do
        put :update, params: { id: 1, data: {} }
        expect(response.status).to eq(409)
      end
    end
  end

  context "when GraphitiErrors disabled" do
    around do |e|
      GraphitiErrors.disable!
      e.run
      GraphitiErrors.enable!
    end

    before do
      raises(CustomStatusError, "some message")
    end

    it "raises exception normally" do
      expect(Rails.logger).to_not receive(:error)
      expect {
        get :index
      }.to raise_error(CustomStatusError, /some message/)
    end
  end

  context "when subclass has its own registry" do
    before do
      raises(SpecialPostError, "some_error")
    end

    context "and parent controller is hit with that error" do
      it "is not customized" do
        get :index, params: {error: "SpecialPostError"}
        expect(error["detail"]).to eq(standard_detail)
      end
    end
  end
end
