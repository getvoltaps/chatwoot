class AddEmailAliasesToChannelEmail < ActiveRecord::Migration[7.0]
  def change
    add_column :channel_email, :email_aliases, :text, default: nil
  end
end
