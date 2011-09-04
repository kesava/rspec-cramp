require "rubygems"
require File.join(File.dirname(__FILE__), "../lib/rspec_cramp")
require "cramp"
require "rspec"
require "http_router"

module Cramp
  
  describe "rspec-cramp" do
    class SuccessfulResponse < Cramp::Action
      def start
        render "ok"
        finish
      end
    end

    class HelloWorldResponse < Cramp::Action
      def start
        render "Hello, world"
        finish
      end
    end
    
    class MultipartResponse < Cramp::Action
      def start
        render "part1"
        render "part2"
        finish
      end
    end

    class ErrorResponse < Cramp::Action
      def respond_with
        [500, {'Content-Type' => 'text/html'}]
      end
      def start
        finish
      end
    end
    
    class RaiseOnStart < Cramp::Action
      def start
        raise "an error"
      end
    end
    
    class NoResponse < Cramp::Action
      def start
      end
    end
    
    class CustomHeaders < Cramp::Action
      def respond_with
        [200, {'Extra-Header' => 'ABCD', 'Another-One' => 'QWERTY'}]
      end
      def start
        render "ok"
        finish
      end
    end
    
    class SseAction < Cramp::Action
      self.transport = :sse
      periodic_timer :write_hello, :every => 0.5
      def write_hello
        @num ||= 1
        render "Hello #{@num}"
        @num += 1
      end
    end
    
    # Entry point
    def app
      HttpRouter.new do
        add('/200').to SuccessfulResponse
        add('/hello_world').to HelloWorldResponse
        add('/multipart').to MultipartResponse
        add('/500').to ErrorResponse
        add('/no_response').to NoResponse
        add('/custom_header').to CustomHeaders
        add('/raise_on_start').to RaiseOnStart
        add('/sse').to SseAction
      end
    end
    
    describe "'respond_with' matcher", :cramp => true do
      shared_examples_for "async_request" do |method|

        describe "timeout" do
          it "- timeout when no response" do
            lambda { send(method, "/no_response") }.should raise_error Timeout::Error
          end
          it "- allow the timeout to be defined by the user" do
            lambda do
              timeout(2) do
                lambda {send(method, "/no_response", {:timeout => 1}) }.should raise_error Timeout::Error
              end
            end.should_not raise_error Timeout::Error
          end
        end
        
        # TODO Rewrite the repetitive code below using data-based spec generation.
        describe "exact match on response status" do
          it "should match successful response" do
            send(method, "/200").should respond_with :status => 200
            send(method, "/200").should respond_with :status => "200"
            send(method, "/200").should respond_with :status => :ok
          end
          it "should match error response" do
            send(method, "/500").should respond_with :status => 500
            send(method, "/500").should respond_with :status => "500"
            send(method, "/500").should respond_with :status => :error
            send(method, "/500").should_not respond_with :status => 200
            send(method, "/500").should_not respond_with :status => "200"
            send(method, "/500").should_not respond_with :status => :ok
          end
          it "should match non-async errors from http router" do
            send(method, "/404").should respond_with :status => 404
            send(method, "/404").should respond_with :status => "404"
          end
        end

        describe "regex match on response status" do
          it "should match successful response" do
            send(method, "/200").should respond_with :status => /^2.*/
          end
          it "should match error response" do
            send(method, "/500").should respond_with :status => /^5.*/
            send(method, "/500").should_not respond_with :status => /^2.*/
          end
          it "should match non-sync errors from http router" do
            send(method, "/404").should respond_with :status => /^4.*/
          end
        end
        
        describe "exact match on response headers" do
          it "should match with one expected header" do
            send(method, "/custom_header").should respond_with :header => {"Extra-Header" => "ABCD"}
          end
          it "should match all with two expected headers" do
            send(method, "/custom_header").should respond_with :header => {"Extra-Header" => "ABCD", "Another-One" => "QWERTY"}
          end
          it "should not match if value does not match" do
            send(method, "/custom_header").should_not respond_with :header => {"Extra-Header" => "1234"}
          end
          it "should not match iff both expected headers do not match" do
            send(method, "/custom_header").should_not respond_with :header => {"Extra-Header" => "1234", "Non-Existent-One" => "QWERTY"}
          end
        end
        
        describe "regex match on response headers" do
          it "should match with one expected header" do
            send(method, "/custom_header").should respond_with :header => {"Extra-Header" => /^ABCD$/}
          end
          it "should match all with two expected headers" do
            send(method, "/custom_header").should respond_with :header => {"Extra-Header" => /^ABCD$/, "Another-One" => /^QWERTY$/}
          end
          it "should not match if value does not match" do
            send(method, "/custom_header").should_not respond_with :header => {"Extra-Header" => /^1234$/}
          end
          it "should not match iff both expected headers do not match" do
            send(method, "/custom_header").should_not respond_with :header => {"Extra-Header" => /^1234$/, "Non-Existent-One" => /^QWERTY$/}
          end
        end
        
        # FIXME How to handle a situation where nothing is rendered? get reads the body...
        
        describe "exact match on response body" do
          it "should match with successful response" do
            send(method, "/200").should respond_with :body => "ok"
            send(method, "/200").should_not respond_with :body => "wrong"
          end
          it "should not load body on error response" do
            # TODO Not sure about this behaviour. What do you think? Use "Something went wrong"?
            send(method, "/500").should respond_with :body => /.*Cramp::Body.*/
          end
          it "should match non-async response from http router" do
            send(method, "/404").should respond_with :body => "Something went wrong"
          end
        end
        describe "regex match on response body" do
          it "should match the body" do
            send(method, "/hello_world").should respond_with :body => /.*Hello.*/
            send(method, "/hello_world").should_not respond_with :body => /.*incorrect.*/
          end
        end
   
        describe "exact match on multipart response body" do
          it "should match with successful response" do
            send(method, "/multipart", :max_chunks => 2).should respond_with :body => "part1part2"
            send(method, "/multipart", :max_chunks => 2).should_not respond_with :body => "whatever"
          end
        end
        describe "regex match on multipart response body" do
          it "should match the body" do
            send(method, "/multipart", :max_chunks => 2).should respond_with :body => /.*part.*/
            send(method, "/multipart", :max_chunks => 2).should_not respond_with :body => /.*incorrect.*/
          end
        end
        
        describe "exact match on response body chunks" do
          it "should match with successful response" do
            send(method, "/multipart", :max_chunks => 2).should respond_with :chunks => ["part1", "part2"]
            send(method, "/multipart", :max_chunks => 2).should_not respond_with :chunks => ["whatever1", "whatever2"]
          end
        end
        describe "regex match on response body chunks" do
          # Note: In theory, an exact match would also work but because the content also contains an event-id, 
          # it is not practical.
          it "should match with successful response" do
            send(method, "/multipart", :max_chunks => 2).should respond_with :chunks => [/part1/, /part2/]
            send(method, "/multipart", :max_chunks => 2).should_not respond_with :chunks => [/whatever1/, /whatever2/]
          end
        end
        
        describe "multiple conditions" do
          it "should match on status and body" do
            send(method, "/200").should respond_with :status => :ok, :body => "ok"
            send(method, "/200").should_not respond_with :status => :ok, :body => "incorrect"
            send(method, "/200").should_not respond_with :status => :error, :body => "ok"
          end
        end
        
        describe "sse support" do
          # Note: In theory, xact match would also work but because the content also contains an event-id, 
          # it is not practical.
          it "should match with successful response" do
            send(method, "/sse", :max_chunks => 2).should respond_with :chunks => [/^data: Hello 1.*/, /^data: Hello 2.*/]
            send(method, "/sse", :max_chunks => 2).should_not respond_with :chunks => [/.*Incorrect 1.*/, /.*Incorrect 2.*/]
          end
        end
        
        it "should correctly handle exception in the callbacks"
        it "should correctly handle exception raised in on_start"
        
        it "should support custom request headers"

      end
          
      describe "GET request" do
        it_should_behave_like "async_request", :get 
      end
    end
  
    # FIXME Better failure message for response matcher.
    describe "'be_matching' matcher", :cramp => true do
      # TODO Only basic matching here because respond_with matcher uses the same method. 
      # It should be the other way around, i.e. all the tests should be here but I hate to rewrite the specs now.
      # Anyway, we need more tests here.
      it "should support expectations on response status" do
        get("/200") do |response|
          response.should be_matching :status => 200
          response.should be_matching :status => :ok
          response.should_not be_matching :status => 500
          stop
        end
      end
      it "should support expectations on response body" do
        get("/200") do |response|
          response.read_body do
            response.body.should == ["ok"]
            response.body.should_not == ["whatever"]
          end
        end
      end
      it "should support array access" do
        get("/200") do |response|
          response[0].should == 200
          response[1].should be_a Hash
          response[2].should be_a Cramp::Body
          response[-1].should be_a Cramp::Body
          stop
        end
      end
      
      describe "improper body access" do
        it "should warn user if body is accessed via an attribute without read_body" do
           get("/200") do |response|
             lambda { response.body }.should raise_error 
             stop
           end
         end       
         it "should warn user if body is accessed via an attribute outside read_body" do
           get("/200") do |response|
             response.read_body
             lambda { response.body }.should raise_error 
             stop
           end
         end
       end
    end
  end
end