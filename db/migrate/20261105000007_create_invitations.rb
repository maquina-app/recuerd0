# An invitation link works once, which takes a row to remember it was used. Links
# signed before this table stop working; an admin generates new ones.
class CreateInvitations < ActiveRecord::Migration[8.0]
  def change
    create_table :invitations do |t|
      t.references :account, null: false, foreign_key: true
      t.datetime :used_at

      t.timestamps
    end

    remove_column :accounts, :invitation_generation, :integer, default: 0, null: false
  end
end
