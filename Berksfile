site :opscode

# apt 1.8.4 requires Chef 10.16.4 or later
cookbook "apt", "1.7.0" 
cookbook "build-essential", "1.3.2"
cookbook "git", "2.1.4"
  
cookbook "passenger_apache2", :git => "https://github.com/articlemetrics/passenger_apache2.git", branch: "articlemetrics"
cookbook "mysql", "2.1.0"
cookbook "couchdb", "2.1.0"
cookbook "phantomjs", "0.0.10"

cookbook "alm", :git => "https://github.com/articlemetrics/alm-cookbook.git"