class Email::SendOnEmailService < Base::SendOnChannelService
  private

  def channel_class
    Channel::Email
  end

  def perform_reply
    return unless message.email_notifiable_message?

    reply_mail = ConversationReplyMailer.with(account: message.account).email_reply(message).deliver_now
    Rails.logger.info("Email message #{message.id} sent with source_id: #{reply_mail.message_id}")
    message.update(source_id: reply_mail.message_id)
    append_to_gmail_sent(reply_mail)
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: message.account).capture_exception
    Messages::StatusUpdateService.new(message, 'failed', e.message).perform
  end

  def append_to_gmail_sent(reply_mail)
    channel = message.inbox&.channel
    return unless channel.is_a?(Channel::Email) && channel.google?

    Imap::GoogleAppendSentService.new(channel: channel, raw_email: reply_mail.to_s).perform
  end
end
