require 'spec_helper'

describe GfobhScorer::Scorer do
  subject(:scorer) do
    described_class.new(
      track,
      stdout: stdout,
      stderr: stderr
    )
  end

  let(:response1) do
    double(
      :response1,
      code: 200,
      body: JSON.unparse({
        seed: 'seed-for-problem-1'
      })
    )
  end

  let(:response2) do
    double(
      :response2,
      code: 200,
      body: JSON.unparse({
        seed: 'seed-for-problem-2'
      })
    )
  end

  let(:final_response) do
    double(:final_response, code: 204)
  end

  let(:generic_response) do
    double(
      :generic_response,
      code: 200,
      body: JSON.unparse({ seed: 'foo' })
    )
  end

  let(:headers) do
    { 'Accept' => 'application/json' }
  end

  let(:not_found_response) do
    double(
      :not_found_response,
      code: 404
    )
  end

  let(:stderr) { StringIO.new }

  let(:stdout) { StringIO.new }

  let(:track) { 'problem_set_1' }

  def make_url(seed = nil, base = GfobhScorer::Scorer::BASE_URL)
    [base, track, seed]
      .compact
      .join('/')
  end

  describe 'When configuring a custom url and example path' do
    subject(:scorer) do
      described_class.new(
        track,
        stdout: stdout,
        stderr: stderr,
        config: {
          base_url: 'http://foo.bar/baz',
          example_1: '/path/to/example'
        }
      )
    end

    it 'hits the correct urls and scripts' do
      expect(RestClient).to receive(:get)
        .with(make_url(nil, 'http://foo.bar/baz'), headers)
        .and_yield(response1)
      expect(subject).to receive(:`)
        .with('/path/to/example \'seed-for-problem-1\'')
        .and_return('answer-for-problem-1')
      expect(RestClient).to receive(:get)
        .with(
          make_url('answer-for-problem-1', 'http://foo.bar/baz'), headers
        )
        .and_yield(final_response)

      expect(subject.run).to eql true
    end
  end

  describe 'When fetching the initial example' do
    before do
      allow(RestClient).to receive(:get)
        .and_yield(generic_response)
      allow(subject).to receive(:`)
        .and_return("")
      expect(RestClient).to receive(:get)
        .with(make_url, headers)
        .and_yield(response1)
      allow(stdout).to receive(:puts)
      allow(stderr).to receive(:puts)

      allow(subject).to receive(:`)
        .with('./bin/example_1 \'seed-for-problem-1\'')
        .and_return('answer-for-problem-1')
    end

    it 'loads the data based on the track of work' do
      subject.run
    end

    describe 'with a correct first answer' do
      before do
        expect(RestClient).to receive(:get)
          .with(make_url('answer-for-problem-1'), headers)
          .and_yield(response2)
      end

      it 'hits the second url' do
        subject.run
      end

      it 'reports the status of the first example' do
        subject.run
        expect(stdout).to have_received(:puts)
          .with(/Finished example 1 in [\d\.]+ seconds/)
      end

      it 'reports the total elapsed time' do
        subject.run
        expect(stdout).to have_received(:puts)
          .with(/Total time for all examples: [\d\.]+ seconds/)
      end

      describe 'with a correct second answer' do
        before do
          allow(subject).to receive(:`)
            .with('./bin/example_2 \'seed-for-problem-2\'')
            .and_return('answer-for-problem-2')
        end

        describe 'when the second example is the last one' do
          before do
            expect(RestClient).to receive(:get)
              .with(make_url('answer-for-problem-2'), headers)
              .and_yield(final_response)
          end

          it 'returns true' do
            expect(subject.run).to eql true
          end
        end
      end
    end

    describe 'with an incorrect first answer' do
      before do
        expect(RestClient).to receive(:get)
          .with(make_url('answer-for-problem-1'), headers)
          .and_yield(not_found_response)
      end

      it 'reports the error to stderr' do
        subject.run
        expect(stderr).to have_received(:puts)
          .with("Your answer for example 1 was incorrect")
      end

      it 'returns false' do
        expect(subject.run).to eql false
      end
    end
  end
end