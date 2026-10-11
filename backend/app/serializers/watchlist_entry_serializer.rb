class WatchlistEntrySerializer
  def self.call(entry)
    {
      id: entry.id,
      priority: entry.priority,
      status: entry.status,
      recommendation: entry.recommendation,
      fit_score: entry.fit_score,
      calculated_fit_score: entry.calculated_fit_score&.to_f,
      fit_breakdown: entry.fit_breakdown,
      fit_calculated_at: entry.fit_calculated_at,
      need_score: entry.need_score,
      cost_score: entry.cost_score,
      risk_score: entry.risk_score,
      review_status: entry.review_status,
      review_statuses: WatchlistEntry::REVIEW_STATUSES,
      candidate_owner: UserSummarySerializer.call(entry.candidate_owner),
      acquisition_rationale: entry.acquisition_rationale,
      estimated_cost: entry.estimated_cost&.to_f,
      availability: entry.availability,
      concerns: entry.concerns,
      tags: entry.tags,
      notes: entry.notes,
      updated_at: entry.updated_at,
      player: {
        id: entry.player.id,
        mlb_id: entry.player.mlb_id,
        full_name: entry.player.full_name,
        headshot_url: entry.player.profile&.headshot_url,
        team: entry.player.display_team && {
          id: entry.player.display_team.id,
          name: entry.player.display_team.name,
          abbreviation: entry.player.display_team.abbreviation
        }
      }
    }
  end
end
