class Imap::GoogleFetchEmailService < Imap::BaseFetchEmailService
  def fetch_emails
    return if channel.provider_config['access_token'].blank?

    fetch_mail_for_channel
  end

  private

  def authentication_type
    'XOAUTH2'
  end

  def imap_password
    Google::RefreshOauthTokenService.new(channel: channel).access_token
  end

  def since
    previous_day = Time.zone.today - 30
    previous_day.strftime('%d-%b-%Y')
  end
end
