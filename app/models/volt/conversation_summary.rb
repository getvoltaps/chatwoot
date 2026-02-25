class Volt::ConversationSummary < ApplicationRecord
  self.table_name = 'volt_conversation_summaries'

  belongs_to :conversation
  belongs_to :account

  validates :content, presence: true
  validates :conversation_id, uniqueness: true

  before_save :update_searchable

  scope :by_account, ->(account_id) { where(account_id: account_id) }

  def self.search_similar(query, account_id:, limit: 3, exclude_conversation_id: nil)
    return none if query.blank?

    scope = by_account(account_id).where('searchable IS NOT NULL')
    scope = scope.where.not(conversation_id: exclude_conversation_id) if exclude_conversation_id

    scope
      .where("searchable @@ plainto_tsquery('english', ?)", query)
      .order(Arel.sql("ts_rank(searchable, plainto_tsquery('english', #{connection.quote(query)})) DESC"))
      .limit(limit)
  end

  private

  def update_searchable
    self.searchable = self.class.connection.execute(
      "SELECT to_tsvector('english', #{self.class.connection.quote(content)})"
    ).first['to_tsvector']
  end
end
