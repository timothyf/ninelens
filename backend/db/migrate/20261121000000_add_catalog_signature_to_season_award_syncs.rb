class AddCatalogSignatureToSeasonAwardSyncs < ActiveRecord::Migration[7.1]
  def change
    add_column :season_award_syncs, :catalog_signature, :string
  end
end
