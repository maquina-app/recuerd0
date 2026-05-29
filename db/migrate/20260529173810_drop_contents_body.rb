class DropContentsBody < ActiveRecord::Migration[8.1]
  # A `body` TEXT column cannot coexist with `has_markdown :body` (which defines
  # body/body=). Drop it after the backfill. Reversal re-adds the column and
  # restores its data from action_text_markdowns.
  def up
    remove_column :contents, :body
  end

  def down
    add_column :contents, :body, :text
    execute <<~SQL
      UPDATE contents SET body = (
        SELECT content FROM action_text_markdowns m
        WHERE m.record_type = 'Content' AND m.record_id = contents.id AND m.name = 'body'
      )
    SQL
  end
end
