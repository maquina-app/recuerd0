class AddOnboardingDismissedAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :onboarding_dismissed_at, :datetime, null: true
  end
end
