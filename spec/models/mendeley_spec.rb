require 'spec_helper'

describe Mendeley do

  subject { FactoryGirl.create(:mendeley) }

  context "CSV report" do
    let(:url) { "#{CONFIG[:couchdb_url]}_design/reports/_view/mendeley" }

    it "should format the CouchDB report as csv" do
      stub = stub_request(:get, url).to_return(:body => File.read(fixture_path + 'mendeley_report.json'))
      response = CSV.parse(subject.to_csv)
      response.count.should == 31
      response.first.should eq(["doi", "readers", "groups", "total"])
      response.last.should eq(["10.5194/se-1-1-2010", "6", "0", "6"])
    end

    it "should report an error if the CouchDB design document can't be retrieved" do
      FactoryGirl.create(:fatal_error_report_with_admin_user)
      stub = stub_request(:get, url).to_return(:status => [404])
      subject.to_csv.should be_nil
      Alert.count.should == 1
      alert = Alert.first
      alert.class_name.should eq("Faraday::ResourceNotFound")
      alert.message.should eq("CouchDB report for Mendeley could not be retrieved.")
      alert.status.should == 404
    end
  end

  context "lookup access token" do
    let(:auth) { ActionController::HttpAuthentication::Basic.encode_credentials(subject.client_id, subject.secret) }

    it "should make the right API call" do
      Time.stub(:now).and_return(Time.mktime(2013, 9, 5))
      subject.access_token = nil
      subject.expires_at = Time.now
      stub = stub_request(:post, subject.authentication_url).with(:body => "grant_type=client_credentials", :headers => { :authorization => auth })
        .to_return(:body => File.read(fixture_path + 'mendeley_auth.json'))
      subject.get_access_token.should be_true
      stub.should have_been_requested
      subject.access_token.should eq("MSwxMzk0OTg1MDcyMDk0LCwxOCwsLElEeF9XU256OWgzMDNlMmc4V0JaVkMyVnFtTQ")
      subject.expires_at.should eq(Time.now + 3600.seconds)
    end

    it "should look up access token if blank" do
      subject.access_token = nil
      article = FactoryGirl.create(:article, :doi => "10.1371/journal.pone.0043007")
      stub_auth = stub_request(:post, subject.authentication_url).with(:headers => { :authorization => auth }, :body => "grant_type=client_credentials")
        .to_return(:body => File.read(fixture_path + 'mendeley_auth.json'))
      stub_uuid = stub_request(:get, subject.get_lookup_url(article))
        .to_return(:body => File.read(fixture_path + 'mendeley.json'))
      stub = stub_request(:get, subject.get_query_url(article)).to_return(:status => [408])

      response = subject.get_data(article, source_id: subject.id)
      response[:error].should_not be_nil
      stub_auth.should have_been_requested
      stub_uuid.should have_been_requested.times(2)
      stub.should have_been_requested
    end

    it "should look up access token if expired" do
      subject.expires_at = Time.zone.now
      article = FactoryGirl.create(:article, :doi => "10.1371/journal.pone.0043007")
      stub_auth = stub_request(:post, subject.authentication_url).with(:headers => { :authorization => auth }, :body => "grant_type=client_credentials")
        .to_return(:body => File.read(fixture_path + 'mendeley_auth.json'))
      stub_uuid = stub_request(:get, subject.get_lookup_url(article))
        .to_return(:body => File.read(fixture_path + 'mendeley.json'))
      stub = stub_request(:get, subject.get_query_url(article)).to_return(:status => [408])

      response = subject.get_data(article, source_id: subject.id)
      response[:error].should_not be_nil
      stub_auth.should have_been_requested
      stub_uuid.should have_been_requested.times(2)
      stub.should have_been_requested
    end

    it "should report that there are no events if access token can't be retrieved" do
      subject.access_token = nil
      article = FactoryGirl.create(:article, :doi => "10.1371/journal.pone.0043007")
      stub = stub_request(:post, subject.authentication_url).with(:headers => { :authorization => auth }, :body => "grant_type=client_credentials")
        .to_return(:body => "Credentials are required to access this resource.", :status => 401)
      subject.get_data(article, options = { :source_id => subject.id }).should eq({})
      stub.should have_been_requested
      Alert.count.should == 1
      alert = Alert.first
      alert.class_name.should eq("Net::HTTPUnauthorized")
      alert.message.should eq("the server responded with status 401 for https://api-oauth2.mendeley.com/oauth/token")
      alert.status.should == 401
    end
  end

  it "should report that there are no events if the doi, pmid, mendeley uuid and title are missing" do
    article_without_ids = FactoryGirl.build(:article, :doi => nil, :pmid => "", :mendeley_uuid => "", :title => "")
    subject.get_data(article_without_ids).should eq({})
  end

  context "use the Mendeley API for uuid lookup" do
    let(:article) { FactoryGirl.build(:article, :doi => "10.1371/journal.pone.0008776", :mendeley_uuid => "") }

    it "should return the Mendeley uuid by the Mendeley API" do
      stub = stub_request(:get, subject.get_lookup_url(article)).to_return(:body => File.read(fixture_path + 'mendeley.json'))
      subject.get_mendeley_uuid(article).should eq("46cb51a0-6d08-11df-afb8-0026b95d30b2")
      stub.should have_been_requested
    end

    it "should return the Mendeley uuid by searching the Mendeley API" do
      article = FactoryGirl.build(:article, :doi => "10.1371/journal.pone.0000001", :mendeley_uuid => "")
      stub = stub_request(:get, subject.get_lookup_url(article)).to_return(:body => File.read(fixture_path + 'mendeley_nil.json'))
      stub_doi = stub_request(:get, subject.get_lookup_url(article, "doi")).to_return(:body => File.read(fixture_path + 'mendeley_nil.json'))
      stub_title = stub_request(:get, subject.get_lookup_url(article, "title")).to_return(:body => File.read(fixture_path + 'mendeley_search.json'))
      subject.get_mendeley_uuid(article).should eq("1779af10-6d0c-11df-a2b2-0026b95e3eb7")
      stub.should have_been_requested
      stub_doi.should have_been_requested
      stub_title.should have_been_requested
    end

    it "should return nil for the Mendeley uuid if the Mendeley API returns malformed response" do
      stub = stub_request(:get, subject.get_lookup_url(article)).to_return(:body => File.read(fixture_path + 'mendeley_nil.json'))
      stub_doi = stub_request(:get, subject.get_lookup_url(article, "doi")).to_return(:body => File.read(fixture_path + 'mendeley_nil.json'))
      stub_title = stub_request(:get, subject.get_lookup_url(article, "title")).to_return(:body => File.read(fixture_path + 'mendeley_search.json'))
      subject.get_mendeley_uuid(article).should be_nil
      stub.should have_been_requested
      stub_doi.should have_been_requested
      stub_title.should have_been_requested
      Alert.count.should == 0
    end

    it "should return nil for the Mendeley uuid if the Mendeley API returns incomplete response" do
      stub = stub_request(:get, subject.get_lookup_url(article)).to_return(:body => File.read(fixture_path + 'mendeley_incomplete.json'))
      stub_doi = stub_request(:get, subject.get_lookup_url(article, "doi")).to_return(:body => File.read(fixture_path + 'mendeley_incomplete.json'))
      stub_title = stub_request(:get, subject.get_lookup_url(article, "title")).to_return(:body => File.read(fixture_path + 'mendeley_search.json'))
      subject.get_mendeley_uuid(article).should be_nil
      stub.should have_been_requested
      stub_doi.should have_been_requested
      stub_title.should have_been_requested
      Alert.count.should == 0
    end
  end

  context "get_data for metrics" do
    it "should report if there are events and event_count returned by the Mendeley API" do
      article = FactoryGirl.build(:article, :doi => "10.1371/journal.pone.0008776", :mendeley_uuid => "46cb51a0-6d08-11df-afb8-0026b95d30b2")
      body = File.read(fixture_path + 'mendeley.json')
      stub_uuid = stub_request(:get, subject.get_lookup_url(article)).to_return(:body => File.read(fixture_path + 'mendeley.json'))
      stub = stub_request(:get, subject.get_query_url(article)).to_return(:body => body)
      response = subject.get_data(article)
      response.should eq(JSON.parse(body))
      stub.should have_been_requested
    end

    it "should report no events and event_count if the Mendeley API returns incomplete response" do
      article = FactoryGirl.build(:article, :doi => "10.1371/journal.pone.0044294")
      body = File.read(fixture_path + 'mendeley_incomplete.json')
      stub_uuid = stub_request(:get, subject.get_lookup_url(article)).to_return(:body => File.read(fixture_path + 'mendeley.json'))
      stub = stub_request(:get, subject.get_query_url(article)).to_return(:body => body)
      response = subject.get_data(article)
      response.should eq(JSON.parse(body))
      stub.should have_been_requested
      Alert.count.should == 0
    end

    it "should report no events and event_count if the Mendeley API returns malformed response" do
      article = FactoryGirl.build(:article, :doi => "10.1371/journal.pone.0044294")
      body = File.read(fixture_path + 'mendeley_nil.json')
      stub_uuid = stub_request(:get, subject.get_lookup_url(article)).to_return(:body => File.read(fixture_path + 'mendeley.json'))
      stub = stub_request(:get, subject.get_query_url(article)).to_return(:body => body, :status => 404)
      response = subject.get_data(article)
      response.should eq(error: JSON.parse(body), status: 404)
      Alert.count.should == 0
    end

    it "should report no events and event_count if the Mendeley API returns not found error" do
      article = FactoryGirl.build(:article)
      body = File.read(fixture_path + 'mendeley_error.json')
      stub_uuid = stub_request(:get, subject.get_lookup_url(article)).to_return(:body => File.read(fixture_path + 'mendeley.json'))
      stub = stub_request(:get, subject.get_query_url(article)).to_return(:body => body, :status => 404)
      response = subject.get_data(article)
      response.should eq(error: JSON.parse(body)['error'], status: 404)
      stub.should have_been_requested
      Alert.count.should == 0
    end

    it "should filter out the mendeley_authors attribute" do
      article = FactoryGirl.build(:article, :doi => "10.1371/journal.pbio.0020002", :mendeley_uuid => "83e9b290-6d01-11df-936c-0026b95e484c")
      body = File.read(fixture_path + 'mendeley_authors_tag.json')
      stub_uuid = stub_request(:get, subject.get_lookup_url(article)).to_return(:body => File.read(fixture_path + 'mendeley_authors_tag.json'))
      stub = stub_request(:get, subject.get_query_url(article)).to_return(:body => body)
      response = subject.get_data(article)
      response.should eq(JSON.parse(body))
      stub.should have_been_requested
    end

    it "should catch timeout errors with the Mendeley API" do
      article = FactoryGirl.build(:article, :doi => "10.1371/journal.pone.0000001")
      stub_uuid = stub_request(:get, subject.get_lookup_url(article)).to_return(:body => File.read(fixture_path + 'mendeley.json'))
      stub = stub_request(:get, subject.get_query_url(article)).to_return(:status => [408])
      response = subject.get_data(article, source_id: subject.id)
      response.should eq(error: "the server responded with status 408 for https://api-oauth2.mendeley.com/oapi/documents/details/#{article.mendeley_uuid}", :status=>408)
      stub.should have_been_requested
      Alert.count.should == 1
      alert = Alert.first
      alert.class_name.should eq("Net::HTTPRequestTimeOut")
      alert.status.should == 408
      alert.source_id.should == subject.id
    end
  end

  context "parse_data for metrics" do
    let(:article) { FactoryGirl.create(:article, :doi => "10.1371/journal.pone.0008776", :mendeley_uuid => "46cb51a0-6d08-11df-afb8-0026b95d30b2") }
    let(:null_response) { { :events=>{}, :events_by_day=>[], :events_by_month=>[], :events_url=>nil, :event_count=>0, :event_metrics=>{:pdf=>nil, :html=>nil, :shares=>0, :groups=>0, :comments=>nil, :likes=>nil, :citations=>nil, :total=>0 } } }

    it "should report if the doi, pmid, mendeley uuid and title are missing" do
      result = {}
      result.extend Hashie::Extensions::DeepFetch
      subject.parse_data(result, article).should eq(null_response)
    end

    it "should report if there are events and event_count returned by the Mendeley API" do
      body = File.read(fixture_path + 'mendeley.json')
      result = JSON.parse(body)
      result.extend Hashie::Extensions::DeepFetch
      response = subject.parse_data(result, article)
      response[:events].should be_true
      response[:events_url].should be_true
      response[:event_count].should eq(4)
    end

    it "should report no events and event_count if the Mendeley API returns incomplete response" do
      body = File.read(fixture_path + 'mendeley_incomplete.json')
      result = JSON.parse(body)
      result.extend Hashie::Extensions::DeepFetch
      subject.parse_data(result, article).should eq(null_response)
      Alert.count.should == 0
    end

    it "should report no events and event_count if the Mendeley API returns malformed response" do
      body = File.read(fixture_path + 'mendeley_nil.json')
      result = { 'data' => body }
      result.extend Hashie::Extensions::DeepFetch
      subject.parse_data(result, article).should eq(null_response)
      Alert.count.should == 0
    end

    it "should report no events and event_count if the Mendeley API returns not found error" do
      body = File.read(fixture_path + 'mendeley_error.json')
      result = { error: JSON.parse(body) }
      result.extend Hashie::Extensions::DeepFetch
      subject.parse_data(result, article).should eq(null_response)
      Alert.count.should == 0
    end

    it "should catch timeout errors with the Mendeley API" do
      article = FactoryGirl.create(:article, :doi => "10.1371/journal.pone.0000001")
      result = { error: "the server responded with status 408 for https://api-oauth2.mendeley.com/oapi/documents/details/#{article.mendeley_uuid}", status: 408 }
      result.extend Hashie::Extensions::DeepFetch
      response = subject.parse_data(result, article)
      response.should eq(result)
    end
  end
end
