# Bumping the generation revokes every invitation link minted before it (U-20).
class AddInvitationGenerationToAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :accounts, :invitation_generation, :integer, default: 0, null: false
  end
end
