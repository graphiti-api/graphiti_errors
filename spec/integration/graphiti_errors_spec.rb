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

  register_exception CustomStatusError,  status: 301
  register_exception CustomTitleError,   title: "My Title"
  register_exception MessageTrueError,   message: true
  register_exception MessageProcError,   message: ->(e) { e.class.name.upcase }
  register_exception MetaProcError,      meta: ->(e) { {class_name: e.class.name.upcase} }
  register_exception LogFalseError,      log: false
  register_exception CustomHandlerError, handler: CustomErrorHandler

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
  register_exception SpecialPostError, message: ->(e) { "special post" }

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

  context "when the error is registered" do
    it "is registered" do
      registered = controller.registered_exception?(CustomStatusError.new)
      expect(registered).to eq true
    end

    context "with custom status" do
      before do
        raises(CustomStatusError, "some message")
      end

      it "returns correct status code" do
        get :index
        expect(response.status).to eq(301)
        expect(error["status"]).to eq("301")
        expect(error["code"]).to eq("moved_permanently")
      end
    end

    context "with custom title" do
      before do
        raises(CustomTitleError, "some message")
      end

      it "returns correct title" do
        get :index
        expect(error["title"]).to eq("My Title")
      end
    end

    context "with message == true" do
      before do
        raises(MessageTrueError, "some message")
      end

      it "shows error message thrown" do
        get :index
        expect(error["detail"]).to eq("some message")
      end
    end

    context "with message as proc" do
      before do
        raises(MessageProcError, "some_error")
      end

      it "shows custom error detail" do
        get :index
        expect(error["detail"]).to eq("MESSAGEPROCERROR")
      end
    end

    context "with meta as proc" do
      before do
        raises(MetaProcError, "some_error")
      end

      it "shows custom error detail" do
        get :index
        expect(error["meta"]).to match("class_name" => "METAPROCERROR")
      end
    end

    context "with log: false" do
      before do
        expect(Rails.logger).to_not receive(:error)
      end

      it "does not log the error" do
        raises(LogFalseError, "some_error")
        get :index
      end
    end

    context "with custom error handling class" do
      before do
        raises(CustomHandlerError, "some message")
      end

      it "returns status customized by that class" do
        get :index
        expect(response.status).to eq(302)
        expect(error["status"]).to eq("302")
        expect(error["code"]).to eq("found")
      end
    end

    context "when a graphiti invalid request error" do
      let(:errors_object) do
        double(:errors, {
          details: {
            'data.attributes.foo': [
              {error: :not_writable},
              {error: :invalid},
            ],
            'included[0].attributes.bar': [
              {error: :unknown_attribute},
            ],
          },
          messages: {
            'data.attributes.foo': [
              "is not writable",
              "is invalid",
            ],
            'included[0].attributes.bar': [
              "is not a known attribute",
            ],
          },
        }).tap do |d|
          allow(d).to receive(:full_message)
            .with(:'data.attributes.foo', "is not writable").and_return("not writable full message")
          allow(d).to receive(:full_message)
            .with(:'data.attributes.foo', "is invalid").and_return("invalid full message")
          allow(d).to receive(:full_message)
            .with(:'included[0].attributes.bar', "is not a known attribute").and_return("unknown attribute full message")
        end
      end

      before do
        raises(Graphiti::Errors::InvalidRequest, errors_object)
      end

      it "returns a bad request error payload" do
        get :index
        expect(response.status).to eq(400)
        expect(json["errors"]).to eq([
          {
            "code" => "bad_request",
            "detail" => "not writable full message",
            "meta" => {
              "attribute" => "data.attributes.foo",
              "code" => "not_writable",
              "message" => "is not writable",
            },
            "source" => {
              "pointer" => "data/attributes/foo",
            },
            "status" => "400",
            "title" => "Request Error",
          },
          {
            "code" => "bad_request",
            "detail" => "invalid full message",
            "meta" => {
              "attribute" => "data.attributes.foo",
              "code" => "invalid",
              "message" => "is invalid",
            },
            "source" => {
              "pointer" => "data/attributes/foo",
            },
            "status" => "400",
            "title" => "Request Error",
          },
          {
            "code" => "bad_request",
            "detail" => "unknown attribute full message",
            "meta" => {
              "attribute" => "included[0].attributes.bar",
              "code" => "unknown_attribute",
              "message" => "is not a known attribute",
            },
            "source" => {
              "pointer" => "included/0/attributes/bar",
            },
            "status" => "400",
            "title" => "Request Error",
          },
        ])
      end
    end
  end

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

    context "and subclass is hit with its registered error" do
      controller(SpecialPostsController) { }

      it "customizes response" do
        get :index
        expect(error["detail"]).to eq("special post")
      end
    end
  end
end
