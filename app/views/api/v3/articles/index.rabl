collection @articles
cache ['v3', @articles]

attributes :doi, :title, :url, :mendeley, :pmid, :pmcid, :publication_date, :update_date, :views, :shares, :bookmarks, :citations, :group_name

unless params[:info] == "summary"
  child :retrieval_statuses => :sources do |rs|
    cache ['v3', rs]
    attributes :name, :display_name, :events_url, :metrics, :update_date

    attributes :events if ["detail","event"].include?(params[:info])
    attributes :by_day, :by_month, :by_year if ["detail","history"].include?(params[:info])
  end
end
