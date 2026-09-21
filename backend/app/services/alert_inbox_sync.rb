class AlertInboxSync
  def self.call(event: nil, user: nil)
    users = user ? User.where(id: user.id) : User.active
    events = event ? PlayerTrendEvent.where(id: event.id) : PlayerTrendEvent.active
    users.find_each do |recipient|
      recipient.alert_subscriptions.enabled.includes(:watchlist).find_each do |subscription|
        events.find_each do |trend_event|
          next unless subscription.matches?(trend_event)

          alert = Alert.find_or_initialize_by(user: recipient, player_trend_event: trend_event)
          alert.alert_subscription = subscription
          alert.supporting_evidence = supporting_evidence(trend_event)
          alert.links = links(trend_event)
          alert.save! if alert.new_record? || alert.changed?
        end
      end
    end
  end

  def self.supporting_evidence(event)
    {
      "baseline" => { "value" => event.baseline_value.to_f, "start_date" => event.baseline_start_date, "end_date" => event.baseline_end_date, "sample_size" => event.baseline_sample_size },
      "current" => { "value" => event.current_value.to_f, "start_date" => event.current_start_date, "end_date" => event.current_end_date, "sample_size" => event.sample_size },
      "change" => { "value" => event.change_value.to_f, "unit" => event.unit, "direction" => event.direction, "threshold" => event.threshold_value.to_f },
      "supporting_pitches" => event.supporting_pitches,
      "metadata" => event.metadata
    }
  end

  def self.links(event)
    player = event.player
    base = "/players/#{player.id}"
    {
      "player" => base,
      "chart" => "#{base}?tab=trends&event_id=#{event.id}",
      "pitch_data" => "#{base}?tab=pitch-data&event_id=#{event.id}",
      "batted_ball" => "#{base}?tab=batted-ball&event_id=#{event.id}"
    }
  end

  private_class_method :supporting_evidence, :links
end
