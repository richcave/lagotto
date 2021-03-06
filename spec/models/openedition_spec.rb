require 'spec_helper'

describe Openedition do
  subject { FactoryGirl.create(:openedition) }

  context "get_data" do
    it "should report that there are no events if the doi is missing" do
      article = FactoryGirl.build(:article, :doi => nil)
      subject.get_data(article).should eq({})
    end

    it "should report if there are no events and event_count returned by the Openedition API" do
      article = FactoryGirl.build(:article, :doi => "10.1371/journal.pone.0000001")
      body = File.read(fixture_path + 'openedition_nil.xml')
      stub = stub_request(:get, subject.get_query_url(article)).to_return(:body => body)
      response = subject.get_data(article)
      response.should eq(Hash.from_xml(body))
      stub.should have_been_requested
    end

    it "should report if there are events and event_count returned by the Openedition API" do
      article = FactoryGirl.build(:article, :doi => "10.2307/683422")
      body = File.read(fixture_path + 'openedition.xml')
      stub = stub_request(:get, subject.get_query_url(article)).to_return(:body => body)
      response = subject.get_data(article)
      response.should eq(Hash.from_xml(body))
      stub.should have_been_requested
    end

    it "should catch errors with the Openedition API" do
      article = FactoryGirl.build(:article, :doi => "10.2307/683422")
      stub = stub_request(:get, subject.get_query_url(article)).to_return(:status => [408])
      response = subject.get_data(article, options = { :source_id => subject.id })
      response.should eq(error: "the server responded with status 408 for http://search.openedition.org/feed.php?op[]=AND&q[]=#{article.doi_escaped}&field[]=All&pf=Hypotheses.org", :status=>408)
      stub.should have_been_requested
      Alert.count.should == 1
      alert = Alert.first
      alert.class_name.should eq("Net::HTTPRequestTimeOut")
      alert.status.should == 408
      alert.source_id.should == subject.id
    end
  end

  context "parse_data" do
    let(:article) { FactoryGirl.build(:article, :doi => "10.1371/journal.pone.0000001") }
    let(:null_response) { { events: [], :events_by_day=>[], :events_by_month=>[], events_url: "http://search.openedition.org/index.php?op[]=AND&q[]=#{article.doi_escaped}&field[]=All&pf=Hypotheses.org", event_count: 0, event_metrics: { pdf: nil, html: nil, shares: nil, groups: nil, comments: nil, likes: nil, citations: 0, total: 0 } } }

    it "should report if the doi is missing" do
      article = FactoryGirl.build(:article, :doi => nil)
      result = {}
      result.extend Hashie::Extensions::DeepFetch
      subject.parse_data(result, article).should eq(events: [], :events_by_day=>[], :events_by_month=>[], events_url: nil, event_count: 0, event_metrics: { pdf: nil, html: nil, shares: nil, groups: nil, comments: nil, likes: nil, citations: 0, total: 0 })
    end

    it "should report if there are no events and event_count returned by the Openedition API" do
      body = File.read(fixture_path + 'openedition_nil.xml')
      result = Hash.from_xml(body)
      result.extend Hashie::Extensions::DeepFetch
      response = subject.parse_data(result, article)
      response.should eq(null_response)
    end

    it "should report if there are events and event_count returned by the Openedition API" do
      article = FactoryGirl.build(:article, :doi => "10.2307/683422", published_on: "2013-05-03")
      body = File.read(fixture_path + 'openedition.xml')
      result = Hash.from_xml(body)
      result.extend Hashie::Extensions::DeepFetch
      response = subject.parse_data(result, article)
      response[:event_count].should eq(1)
      response[:events_url].should eq("http://search.openedition.org/index.php?op[]=AND&q[]=#{article.doi_escaped}&field[]=All&pf=Hypotheses.org")

      response[:events_by_day].length.should eq(1)
      response[:events_by_day].first.should eq(year: 2013, month: 5, day: 27, total: 1)
      response[:events_by_month].length.should eq(1)
      response[:events_by_month].first.should eq(year: 2013, month: 5, total: 1)

      event = response[:events].first
      event[:event_time].should eq("2013-05-27T00:00:00Z")
      event[:event_url].should eq(event[:event]['link'])
    end

    it "should catch timeout errors with the OpenEdition APi" do
      article = FactoryGirl.create(:article, :doi => "10.2307/683422")
      result = { error: "the server responded with status 408 for http://search.openedition.org/feed.php?op[]=AND&q[]=#{article.doi_escaped}&field[]=All&pf=Hypotheses.org", status: 408 }
      response = subject.parse_data(result, article)
      response.should eq(result)
    end
  end
end
