require File.expand_path("../../../support/helpers", __FILE__)
require File.expand_path("../../../support/backend_examples", __FILE__)

require "momentum"
require "rack"
require 'webmock/rspec'

describe Momentum::Adapters::Proxy do
  context 'As a backend' do
    let(:backend) do
      stub_request(:get, "http://localhost:5556/").
        with(:headers => given_request_headers).
        to_return(:status => given_response_status, :body => given_response_body, :headers => given_response_headers)

      app = Momentum::Adapters::Proxy.new('localhost', 5556)
      Momentum::Backend.new(app)
    end

    include_examples "Momentum backend"
  end

  let(:backend) do
    app = Momentum::Adapters::Proxy.new('localhost', 5556)
    Momentum::Backend.new(app)
  end

  it "passes the request body on" do
    stub_request(:post, "http://localhost:5556/").
      with(:body => 'ohai').
      to_return(:status => 200, :body => 'yep', :headers => {})

    request = Momentum::Request.new(:headers => { 'method' => 'post', 'version' => 'HTTP/1.1', 'url' => '/', 'host' => 'localhost', 'scheme' => 'http' })
    request.spdy_info[:body] = 'ohai'

    response = backend.prepare(request)
    response.on_body do |data|
      data.should == 'yep'
    end

    EM.run do
      response.dispatch!
      EM.stop
    end
  end
end