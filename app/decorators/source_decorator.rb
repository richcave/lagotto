class SourceDecorator < Draper::Decorator
  delegate_all
  decorates_association :group

  def state
    human_state_name
  end

  def group
    object.group.name
  end

  def jobs
    { "working" => working_count,
      "pending" => pending_count }
  end

  def responses
    { "count" => response_count,
      "average" => average_count,
      "maximum" => maximum_count }
  end

  def status
    { "refreshed" => articles_count - (stale_count + queued_count),
      "queued" => queued_count,
      "stale" => stale_count }
  end

  def by_day
    { "with_events" => with_events_by_day_count,
      "without_events" => without_events_by_day_count,
      "not_updated" => articles_count - (with_events_by_day_count + without_events_by_day_count) }
  end

  def by_month
    { "with_events" => with_events_by_month_count,
      "without_events" => without_events_by_month_count,
      "not_updated" => articles_count - (with_events_by_month_count + without_events_by_month_count) }
  end
end
