object @status, :object_root => false
cache [@status.articles_count]

attributes :machine_name, :version
node(:status) { "OK" }
attributes :articles_count, :update_date
