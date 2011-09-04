module Cramp
  
  # Response from get, post etc. methods called in rspecs.
  class MockResponse
    def initialize(response)
      @status = response[0]
      @headers = response[1]
      @body = response[2]
    end
    
    def read_body(max_chunks = 1, &block)
      if @body.is_a? Cramp::Body
        stopping = false
        deferred_body = @body
        chunks = []
        deferred_body.each do |chunk|
          chunks << chunk unless stopping
          if chunks.count >= max_chunks
            @body = chunks
            stopping = true
            block.call if block
            EM.next_tick { EM.stop }
          end            
        end
      end
    end
    
    def [](i)
      [@status, @headers, @body][i]
    end
    
    def body
      if @body.is_a? Cramp::Body
        raise "Error: Something went wrong or body is not loaded yet (use response.read_body do { })."
      end
      @body
    end
    
    def headers
      @headers
    end
    
    def status
      @status
    end
    
    def matching?(match_options)
      expected_status = match_options.delete(:status)
      expected_header = match_options.delete(:header)
      expected_body = match_options.delete(:body)
      expected_chunks = match_options.delete(:chunks)
      matching_status?(expected_status) && matching_headers?(expected_header) && matching_body?(expected_body) &&
        matching_chunks?(expected_chunks)
    end
    
    def last_failure_message_for_should
      # TODO Better failure message showing the specific mismatches that made it fail.
      "expected #{@failure_info[:expected]} in #{@failure_info[:what].to_s} but got: \"#{@failure_info[:actual]}\""
    end
    def last_failure_message_for_should_not
      # TODO Better failure message showing the specific successful matches that made it fail.
      "expected response not to match the conditions but got: #{[@status, @headers, @body].inspect}"
    end
    
    private
    
    def matching_response_element?(what, actual, expected)
      is_match = if expected.nil?
        true  # No expectation set.
      elsif actual.nil?
        false
      elsif expected.is_a? Regexp
        actual.to_s.match(expected)
      elsif expected.is_a? Integer
        actual.to_i == expected
      elsif expected.is_a? String
        actual.to_s == expected
      else
        raise "Unsupported type"
      end
      @failure_info = is_match ? {} : {:what => what, :actual => actual, :expected => format_expected(expected)}
      is_match
    end
    
    def resolve_status(status)
      case status
      when :ok then /^2[0-9][0-9]$/
      when :error then /^[^2][0-9][0-9]$/
      else status
      end
    end
    
    def format_expected(expected)
      expected.is_a?(Regexp) ? "/#{expected.source}/" : expected.inspect
    end
    
    def matching_status?(expected_status)
      matching_response_element?(:status, @status, resolve_status(expected_status))
    end
    
    def matching_headers?(expected_header)
      expected_header.nil? || expected_header.find do |ek, ev| 
        @headers.find { |ak, av| ak == ek && !matching_response_element?(:header, av, ev) } != nil
      end == nil 
    end
    
    def matching_body?(expected_body)
      actual_body = @body.is_a?(Array) ? @body.join("") : @body
      matching_response_element?(:body, actual_body, expected_body)
    end
    
    def matching_chunks?(expected_chunks)
      expected_chunks.nil? || (@body.is_a?(Array) && 
        @body.zip(expected_chunks).find do |actual, expected|
          !matching_response_element?(:chunks, actual, expected)
        end.nil?)
    end
  end
end