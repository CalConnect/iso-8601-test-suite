# frozen_string_literal: true

require_relative "../../lib/test_suite/load_result"

RSpec.describe LoadResult do
  describe ".success" do
    subject(:result) { described_class.success({ "id" => "test" }) }

    it { is_expected.to be_success }
    it { is_expected.not_to be_failure }

    it "provides data" do
      expect(result.data).to eq({ "id" => "test" })
    end

    it "raises on error_message" do
      expect { result.error_message }.to raise_error(RuntimeError)
    end
  end

  describe ".failure" do
    subject(:result) { described_class.failure("something broke") }

    it { is_expected.not_to be_success }
    it { is_expected.to be_failure }

    it "provides error_message" do
      expect(result.error_message).to eq("something broke")
    end

    it "raises on data" do
      expect { result.data }.to raise_error(RuntimeError)
    end
  end
end
