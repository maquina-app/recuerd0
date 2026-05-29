class BackfillContentMarkdown < ActiveRecord::Migration[8.1]
  # Move every contents.body string into an action_text_markdowns row
  # (record_type "Content", name "body"). Covers all versions, since each
  # memory version owns its own Content record. Runs via raw SQL so no model
  # callbacks fire — the FTS index is untouched and stays correct.
  def up
    execute <<~SQL
      INSERT INTO action_text_markdowns (record_type, record_id, name, content, created_at, updated_at)
      SELECT 'Content', id, 'body', COALESCE(body, ''), datetime('now'), datetime('now')
      FROM contents
    SQL
  end

  def down
    execute <<~SQL
      DELETE FROM action_text_markdowns WHERE record_type = 'Content' AND name = 'body'
    SQL
  end
end
