require 'net/imap'

class Imap::GoogleAppendSentService
  pattr_initialize [:channel!, :raw_email!]

  def perform
    imap = build_imap_client
    imap.append('[Gmail]/Sent Mail', raw_email, [:Seen], Time.current)
    imap.logout
  rescue StandardError => e
    Rails.logger.error "[IMAP::APPEND_SENT] Failed for #{channel.email}: #{e.message}"
    imap&.disconnect rescue nil # rubocop:disable Style/RescueModifier
  end

  private

  def build_imap_client
    access_token = Google::RefreshOauthTokenService.new(channel: channel).access_token
    imap = Net::IMAP.new('imap.gmail.com', port: 993, ssl: true)
    imap.authenticate('XOAUTH2', channel.imap_login, access_token)
    imap
  end
end
