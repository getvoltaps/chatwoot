/* global axios */

import ApiClient from '../ApiClient';

class VoltAPI extends ApiClient {
  constructor() {
    super('integrations/volt', { accountScoped: true });
  }

  search(query) {
    return axios.get(`${this.url}/search`, {
      params: { q: query },
    });
  }

  getEditions() {
    return axios.get(`${this.url}/editions`);
  }

  generateAiDraft(conversationId, agentContext = null) {
    const payload = { conversation_id: conversationId };
    if (agentContext) payload.agent_context = agentContext;
    return axios.post(`${this.url}/ai_draft`, payload);
  }

  getAiStats() {
    return axios.get(`${this.url}/ai_stats`);
  }

  backfillAiConversations() {
    return axios.post(`${this.url}/ai_backfill`);
  }

  getEditionReport({ since, until: untilDate } = {}) {
    return axios.get(`${this.url}/edition_report`, {
      params: { since, until: untilDate },
    });
  }
}

export default new VoltAPI();
