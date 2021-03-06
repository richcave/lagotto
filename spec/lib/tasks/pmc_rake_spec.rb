require 'spec_helper'

describe "pmc:update" do
  include_context "rake"

  let(:pmc) { FactoryGirl.create(:pmc) }
  let(:month) { 1.month.ago.month }
  let(:year) { 1.month.ago.year }
  let(:output) { "PMC Usage stats for month #{month} and year #{year} have been saved\nPMC Usage stats for month #{month} and year #{year} have been parsed\n" }

  before(:each) do
    pmc.put_lagotto_data(pmc.url)
  end

  after(:each) do
    pmc.delete_lagotto_data(pmc.url)
  end

  its(:prerequisites) { should include("environment") }

  it "should run the rake task" do
    config = pmc.publisher_configs.first
    publisher_id = config["publisher_id"]
    journal = config["config"].journals.split(" ").first
    stub = stub_request(:get, pmc.get_feed_url(publisher_id, month, year, journal)).to_return(:headers => { "Content-Type" => "application/xml" }, :body => File.read(fixture_path + 'pmc.xml'), :status => 200)
    capture_stdout { subject.invoke }.should eq(output)
  end
end
