require "#{File.dirname(__FILE__)}/spec_helper"

require 'rack/request'
require 'rack/mock'

describe FacebookRb do
  APP_NAME = 'my_app'
  SECRET = "123456789"
  API_KEY = "616313"

  it 'should correctly calculate and validate signatures' do
    pending
  end
  
  describe "when the fb_sig is valid" do
    it "should not touch parameters not prefixed with \"fb_sig\"" do
    end
    it "should convert the request method from POST to the original client method" do
    end
    it "should call app" do
    end
  end
end
