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

  generateAiDraft(conversationId) {
    return axios.post(`${this.url}/ai_draft`, {
      conversation_id: conversationId,
    });
  }
}

export default new VoltAPI();
