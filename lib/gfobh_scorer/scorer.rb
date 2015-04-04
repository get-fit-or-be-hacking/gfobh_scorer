require 'json'
require 'restclient'

module GfobhScorer
  class Scorer
    BASE_URL = 'https://gfobh.herokuapp.com'

    def initialize(track_name, opts = {})
      @track_name = track_name
      @stdout = opts[:stdout] || STDOUT
      @stderr = opts[:stderr] || STDERR
      @config = opts[:config] || {}
      @current_example = 1
    end

    def run
      # grab our inital seed value for this example se
      curr = fetch_initial_seed

      # loop through til we get a wrong answer (curr is false) or
      # we have reached the end (curr is true)
      while (curr = run_current_example(curr)) && curr.is_a?(String)
        report_success
        @current_example += 1
      end

      report_results(curr)
      curr
    end

    private

    attr_reader :config, :current_example, :stdout, :stderr, :track_name

    def base_url
      config[:base_url] || BASE_URL
    end

    #
    # Run the current example script, benchmarking the
    # amount of time it takes
    #
    # @param seed [String]
    #
    # @return [String] Result of the script
    def benchmark_current_example(seed)
      start = Time.now
      ret = `#{current_example_script} #{seed}`
      timings[current_example] = (Time.now - start).to_f
      ret.to_s.strip
    end

    #
    # Get the name of the current example to run
    #
    # @return [type] [description]
    def current_example_script
      config["example_#{current_example}".to_sym] ||
        "./bin/example_#{current_example}"
    end


    #
    # alias for verify_current_answer with no args
    #
    # @return [String]
    def fetch_initial_seed
      verify_current_answer
    end

    #
    # Wrapper method to handle track-level reporting
    #
    # @param success [Boolean]
    #
    # @return [nil]
    def report_results(success)
      if success

      else
        report_failure
      end

      report_total_time

      nil
    end

    #
    # Helper function to print the total time it took
    #
    # @return [String]
    def report_total_time
      stdout.puts(
        sprintf(
          "Total time for all examples: %.4f seconds",
          timings.values.reduce(0, :+)
        )
      )
    end

    #
    # Helper function to print a failure message
    #
    # @return [nil]
    def report_failure
      stderr.puts(
        "Your answer for example #{current_example} was incorrect"
      )
      nil
    end

    #
    # Helper function to print a success message
    #
    # @return [nil]
    def report_success
      stdout.puts(
        sprintf(
          "Finished example #{current_example} in %.4f seconds.",
          timings[current_example]
        )
      )
      nil
    end

    #
    # Runs current example and verifies the
    # retsult
    #
    # @param seed [String] Seed value from the last example
    #
    # @return [Boolean, String] True if it was correct and this
    # is the last example, false if incorrect, String value if there
    # are more examples to run
    def run_current_example(seed)
      answer = benchmark_current_example(seed)
      return false if answer.empty?
      verify_current_answer(answer)
    end

    #
    # Hashmap of example timings
    #
    # @return [Hash]
    def timings
      @timings ||= {}
    end


    #
    # Verify the answer from a script against our server
    #
    # @param answer = nil [String] Answer to the current example
    #
    # @return [Boolean, String] True if it was correct and this
    # is the last example, false if incorrect, String value if there
    # are more examples to run
    def verify_current_answer(answer = nil)
      full_url = [base_url, track_name, answer].compact.join('/')
      RestClient.get(full_url) do |response|
        case response.code
        # success
        when 200
          JSON.parse(response.body)['seed']
        # success and it's the last example
        when 204
          true
        # failure
        when 404
          false
        else
          stderr.puts(
            "Something has gone wrong.  Please try again"
          )
          Kernel.exit(1)
        end
      end
    end
  end
end
