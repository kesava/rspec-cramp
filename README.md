A set of rspec matchers and helpers that make it easier to write specs for [cramp](http://cramp.in).

Quick start
-----------

	> gem install rspec-cramp
	


	require 'rspec/cramp'

	# Decorate your spec with :cramp => true
	describe HelloWorld, :cramp => true do

	  # You need to define this method
	  def app
	    HelloWorld # Here goes your cramp application, action or http routes.
	  end

	  # Matching on status code.
	  it "should respond to a GET request" do
	    get("/").should respond_with :status => :ok         # Matches responses from 200 to 299.
	    get("/").should respond_with :status => 200         # Matches only 200.
	    get("/").should respond_with :status => "200"       # Same as above.
	    get("/").should respond_with :status => /^2.*/      # Matches response codes starting with 2.
	    get("/").should_not respond_with :status => :error  # Matches any HTTP error.
	  end

	  # Matching on response body.
	  it "should respond with text starting with 'Hello'" do
	    get("/").should respond_with :body => /^Hello.*/
	  end
	  it "should respond with 'Hello, world!'" do
	    get("/").should respond_with :body => "Hello, world!"
	  end

	  # Matching on response headers.
	  it "should respond with html" do
	    get("/").should respond_with :headers => {"Content-Type" => "text/html"}
	    get("/").should_not respond_with :headers => {"Content-Type" => "text/plain"}
	    get("/").should_not respond_with :headers => {"Unexpected-Header" => /.*/}
	  end

	  # Matching using lambdas.
	  it "should match my sophisticated custom matchers" do
	    # Entire headers.
	    status_check = lambda {|status| status.between?(200, 299)}
	    body_check = lambda {|body| body =~ /.*el.*/}
	    headers_check = lambda {|headers| true} # Any headers will do.
	    get("/").should respond_with :status => status_check, :body => body_check, :headers => headers_check
	    # Header value.
	    get("/").should respond_with :headers => {"Content-Type" => lambda {|value| value == "text/html"}}
	    get("/").should_not respond_with :headers => {"Content-Type" => lambda {|value| value == "text/plain"}}
	  end

	  # Supports POST/GET/PUT/DELETE and you don't have to use the matcher.
	  it "should work without a matcher" do
	    get "/"
	    post "/"
	    put "/"
	    delete "/"
	  end

	  # Request params & custom headers.
	  it "should accept my params" do
	    post("/", :params => {:text => "whatever"}, :headers => {"Custom-Header" => "blah"})
	  end
	end
	
The matcher is fairly flexible, supports regular expressions and also works with multipart responses (more than one `Cramp::Action.render`), SSE and so on. I'll create more examples and docs but for the time being, pls. take a look at the code and [examples](https://github.com/bilus/rspec-cramp/tree/master/spec/examples).

**DISCLAIMER:** I haven't done any work with WebSockets yet so if there is anyone willing to add support for WebSockets, please [tweet me](http://twitter.com/#!/MartinBilski)

Project status
--------------	

**IMPORTANT:** This is work in progress. 

There are still some things I'll take care of soon (esp. better failure messages).

If you have any comments regarding the code as it is now (I know it's a bit messy), please feel free to tweet [@MartinBilski](http://twitter.com/#!/MartinBilski)

Contributors
------------

[Ivan Fomichev](https://github.com/codeholic)

Notes
----

1. The previous version had a problem handling exceptions raised in `on_start` or `on_finish` or with `on_start` that called `finish` without rendering anything because the request helper methods always try to read one body chunk after a successful response (200-299).   
  
	Actually, it wasn't a very big deal, the call would simply time out and raise `Timeout::Error` with a special error message hinting at the problem: *execution expired (No render call in action?)*.
	
	The current version, comes with a [monkey-patched `Cramp::Action`](https://github.com/bilus/rspec-cramp/tree/master/lib/rspec_cramp.rb) which now renders the exception info if it is raised in `on_start` or in `on_finish`.  
	
	See [this example spec](https://github.com/bilus/rspec-cramp/tree/master/spec/examples/errors_spec.rb) to see error handling in action.
	
	I'm definitely open to suggestions, especially how this can be fixed without the cramp surgery. Is the original timeout-based solution better? Unfortunately, the matcher by default always loads one chunk of response body for a successful response.

2. This work is based on [Pratik Naik's code](https://github.com/lifo/cramp/blob/master/lib/cramp/test_case.rb) and writing specs in a similar fashion is still supported though I added a helper for loading the body and a response matcher and some accessors to make your life easier.  

		describe MyCrampAction, :cramp => true do
			def app
				MyCrampAction
			end
			it "should respond to a GET request" do
				get("/") do |response|
					response.status.should == 200
					response.headers.should have_key "Content-Type"
					response.should be_matching :status => :ok
					stop # This is important.
				end
			end
			it "should match the body" do
				get("/") do |response|
					response.read_body do
						response.body.should include "Hello, world!"  # MockResponse::body returns an Array.
						response.should be_matching :body => "Hello, world!"
						# Note: no call to stop here.
					end
				end
			end
		end  
	
	In general, I recommend using the 'respond_with' matcher whenever possible; I think it makes the specs more readable because it hides some gory details (for good or bad). But they are useful when you're debugging your cramp application if the failure message doesn't include all the details you need.
