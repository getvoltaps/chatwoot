namespace :volt do
  desc 'Index resolved conversations for RAG-powered AI drafts'
  task index_conversations: :environment do
    account_id = ENV.fetch('ACCOUNT_ID', nil)
    batch_size = ENV.fetch('BATCH_SIZE', 100).to_i
    limit = ENV.fetch('LIMIT', nil)

    scope = Conversation.where(status: :resolved)
                        .joins(:messages)
                        .where(messages: { message_type: [:incoming, :outgoing] })
                        .distinct

    scope = scope.where(account_id: account_id) if account_id.present?

    existing_ids = Volt::ConversationSummary.pluck(:conversation_id)
    scope = scope.where.not(id: existing_ids) if existing_ids.any?

    scope = scope.limit(limit.to_i) if limit.present?

    total = scope.count
    puts "Indexing #{total} resolved conversations..."

    processed = 0
    scope.find_each(batch_size: batch_size) do |conversation|
      Volt::IndexConversationJob.perform_later(conversation.id)
      processed += 1
      puts "Enqueued #{processed}/#{total}" if (processed % 100).zero?
    end

    puts "Done. Enqueued #{processed} jobs."
  end
end
