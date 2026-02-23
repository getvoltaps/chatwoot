class Mailbox::ConversationFinder
  DEFAULT_STRATEGIES = [
    Mailbox::ConversationFinderStrategies::ReceiverUuidStrategy,
    Mailbox::ConversationFinderStrategies::InReplyToStrategy,
    Mailbox::ConversationFinderStrategies::ReferencesStrategy,
    Mailbox::ConversationFinderStrategies::NewConversationStrategy
  ].freeze

  def initialize(mail, strategies: DEFAULT_STRATEGIES)
    @mail = mail
    @strategies = strategies
  end

  def find
    sender_email = @mail.from&.first&.downcase

    @strategies.each do |strategy_class|
      conversation = strategy_class.new(@mail).find
      next unless conversation

      # VOLT PATCH: If this is not a new conversation strategy and the sender
      # is different from the conversation's contact, create a new conversation instead.
      if strategy_class != Mailbox::ConversationFinderStrategies::NewConversationStrategy
        contact_email = conversation.contact&.email&.downcase
        if contact_email && sender_email && contact_email != sender_email
          Rails.logger.info "Volt patch: sender #{sender_email} differs from contact #{contact_email}, creating new conversation"
          next
        end
      end

      strategy_name = strategy_class.name.demodulize.underscore
      Rails.logger.info "Conversation found via #{strategy_name} strategy"
      return conversation
    end

    Rails.logger.error 'No conversation found via any strategy (NewConversationStrategy missing?)'
    nil
  end
end