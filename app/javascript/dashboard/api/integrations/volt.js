/* global axios */

import ApiClient from '../ApiClient';

const log = (method, url, data) => {
  if (data) console.log(`[VoltAPI] ${method} ${url}`, data);
  else console.log(`[VoltAPI] ${method} ${url}`);
};

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

  // Twilio Queue Management
  getTwilioEditions() {
    log('GET', 'twilio_editions');
    return axios.get(`${this.url}/twilio_editions`);
  }

  getTwilioEdition(editionId) {
    log('GET', `twilio_editions/${editionId}`);
    return axios.get(`${this.url}/twilio_editions/${editionId}`);
  }

  addTwilioEditionAgent(editionId, data) {
    log('POST', `twilio_editions/${editionId}/agents`, data);
    return axios.post(
      `${this.url}/twilio_editions/${editionId}/agents`,
      data
    );
  }

  removeTwilioEditionAgent(editionId, assignmentId) {
    log('DELETE', `twilio_editions/${editionId}/agents/${assignmentId}`);
    return axios.delete(
      `${this.url}/twilio_editions/${editionId}/agents/${assignmentId}`
    );
  }

  getTwilioQueues() {
    log('GET', 'twilio_queues');
    return axios.get(`${this.url}/twilio_queues`);
  }

  // Agent identity CRUD
  getTwilioAgents() {
    log('GET', 'twilio_agents');
    return axios.get(`${this.url}/twilio_agents`);
  }

  getTwilioAgent(agentId) {
    log('GET', `twilio_agents/${agentId}`);
    return axios.get(`${this.url}/twilio_agents/${agentId}`);
  }

  addTwilioAgent(data) {
    log('POST', 'twilio_agents', data);
    return axios.post(`${this.url}/twilio_agents`, data);
  }

  updateTwilioAgent(agentId, data) {
    log('PUT', `twilio_agents/${agentId}`, data);
    return axios.put(`${this.url}/twilio_agents/${agentId}`, data);
  }

  deleteTwilioAgent(agentId) {
    log('DELETE', `twilio_agents/${agentId}`);
    return axios.delete(`${this.url}/twilio_agents/${agentId}`);
  }

  // Agent assignment CRUD
  getAgentAssignments(agentId) {
    log('GET', `twilio_agents/${agentId}/assignments`);
    return axios.get(`${this.url}/twilio_agents/${agentId}/assignments`);
  }

  addAgentAssignment(agentId, data) {
    log('POST', `twilio_agents/${agentId}/assignments`, data);
    return axios.post(
      `${this.url}/twilio_agents/${agentId}/assignments`,
      data
    );
  }

  updateAgentAssignment(agentId, assignmentId, data) {
    log('PUT', `twilio_agents/${agentId}/assignments/${assignmentId}`, data);
    return axios.put(
      `${this.url}/twilio_agents/${agentId}/assignments/${assignmentId}`,
      data
    );
  }

  deleteAgentAssignment(agentId, assignmentId) {
    log('DELETE', `twilio_agents/${agentId}/assignments/${assignmentId}`);
    return axios.delete(
      `${this.url}/twilio_agents/${agentId}/assignments/${assignmentId}`
    );
  }

  // Twilio Opening Hours
  getOpeningHours() {
    log('GET', 'twilio_opening_hours');
    return axios.get(`${this.url}/twilio_opening_hours`);
  }

  getQueueHours(queueName) {
    log('GET', `twilio_opening_hours/queue/${queueName}`);
    return axios.get(`${this.url}/twilio_opening_hours/queue/${queueName}`);
  }

  updateQueueHours(queueName, data) {
    log('PUT', `twilio_opening_hours/queue/${queueName}`, data);
    return axios.put(
      `${this.url}/twilio_opening_hours/queue/${queueName}`,
      data
    );
  }

  getEditionHours(editionId) {
    log('GET', `twilio_opening_hours/edition/${editionId}`);
    return axios.get(
      `${this.url}/twilio_opening_hours/edition/${editionId}`
    );
  }

  updateEditionHours(editionId, data) {
    log('PUT', `twilio_opening_hours/edition/${editionId}`, data);
    return axios.put(
      `${this.url}/twilio_opening_hours/edition/${editionId}`,
      data
    );
  }

  deleteEditionHours(editionId) {
    log('DELETE', `twilio_opening_hours/edition/${editionId}`);
    return axios.delete(
      `${this.url}/twilio_opening_hours/edition/${editionId}`
    );
  }
}

export default new VoltAPI();
