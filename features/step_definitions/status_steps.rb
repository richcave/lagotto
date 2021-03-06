### GIVEN ###
Given /^that we have added (\d+) documents to CouchDB$/ do |number|
  number.to_i.times do |i|
    put_lagotto_data("#{CONFIG[:couchdb_url]}#{i}", data: { "name" => "Fred" })
  end
end

Given /^we have refreshed the status cache$/ do
  Status.new.update_cache
end

### THEN ###
Then /^I should see that the CouchDB size is "(.*?)"$/ do |size|
  within("#couchdb_size") do
    page.should have_content('KB')
  end
end

Then /^I should see that we have (\d+) articles$/ do |number|
  page.has_css?('#articles_count', :text => number).should be_true
end

Then /^I should see that we have (\d+) recent articles$/ do |number|
  page.has_css?('#articles_last30_count', :text => number).should be_true
end

Then /^I should see that we have (\d+) events$/ do |number|
  page.has_css?('#events_count', :text => number).should be_true
end

Then /^I should see that we have (\d+) users?$/ do |number|
  page.has_css?('#users_count', :text => number).should be_true
end

Then /^I should not see that we have (\d+) users?$/ do |number|
  page.has_no_content?('#users_count', :text => number).should be_true
end

Then /^I should see that we have (\d+) active sources?$/ do |number|
  page.has_css?('#sources_active_count', :text => number).should be_true
end
