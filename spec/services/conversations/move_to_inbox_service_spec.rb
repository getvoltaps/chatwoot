require 'rails_helper'

RSpec.describe Conversations::MoveToInboxService do
  let(:account) { create(:account) }
  let(:source_inbox) { create(:inbox, :with_email, account: account) }
  let(:target_inbox) { create(:inbox, :with_email, account: account) }
  let(:contact) { create(:contact, account: account, email: 'customer@example.com') }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: source_inbox, source_id: contact.email) }
  let(:conversation) do
    create(:conversation, account: account, inbox: source_inbox, contact: contact, contact_inbox: contact_inbox)
  end

  describe '#perform' do
    it 'moves the conversation to the target inbox' do
      described_class.new(conversation: conversation, target_inbox: target_inbox).perform
      expect(conversation.reload.inbox_id).to eq(target_inbox.id)
    end

    it 'repoints contact_inbox to one belonging to the target inbox' do
      described_class.new(conversation: conversation, target_inbox: target_inbox).perform
      expect(conversation.reload.contact_inbox.inbox_id).to eq(target_inbox.id)
      expect(conversation.contact_inbox.source_id).to eq(contact.email)
    end

    it 'migrates existing message inbox_ids to the target inbox' do
      create(:message, account: account, inbox: source_inbox, conversation: conversation)
      described_class.new(conversation: conversation, target_inbox: target_inbox).perform
      expect(conversation.reload.messages.where.not(inbox_id: target_inbox.id)).to be_empty
    end

    it 'creates an activity message recording the move' do
      expect do
        described_class.new(conversation: conversation, target_inbox: target_inbox).perform
      end.to change { conversation.messages.where(message_type: :activity).count }.by(1)
    end

    it 'raises when target inbox is in a different account' do
      other_account = create(:account)
      other_inbox = create(:inbox, :with_email, account: other_account)
      expect do
        described_class.new(conversation: conversation, target_inbox: other_inbox).perform
      end.to raise_error(StandardError)
    end

    it 'raises when target inbox equals the current inbox' do
      expect do
        described_class.new(conversation: conversation, target_inbox: source_inbox).perform
      end.to raise_error(StandardError)
    end

    it 'raises when target inbox is not an email inbox' do
      web_inbox = create(:inbox, account: account)
      expect do
        described_class.new(conversation: conversation, target_inbox: web_inbox).perform
      end.to raise_error(StandardError)
    end
  end
end
