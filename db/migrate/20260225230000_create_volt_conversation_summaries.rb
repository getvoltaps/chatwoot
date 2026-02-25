class CreateVoltConversationSummaries < ActiveRecord::Migration[7.0]
  def change
    create_table :volt_conversation_summaries do |t|
      t.bigint :conversation_id, null: false
      t.bigint :account_id, null: false
      t.text :content, null: false
      t.column :searchable, :tsvector

      t.timestamps
    end

    add_index :volt_conversation_summaries, :conversation_id, unique: true
    add_index :volt_conversation_summaries, :account_id
    add_index :volt_conversation_summaries, :searchable, using: :gin
  end
end
