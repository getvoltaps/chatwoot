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

  // Twilio Queue Management
  getTwilioEditions() {
    return axios.get(`${this.url}/twilio_editions`);
  }

  getTwilioEdition(editionId) {
    return axios.get(`${this.url}/twilio_editions/${editionId}`);
  }

  addTwilioEditionAgent(editionId, data) {
    return axios.post(
      `${this.url}/twilio_editions/${editionId}/agents`,
      data
    );
  }

  removeTwilioEditionAgent(editionId, assignmentId) {
    return axios.delete(
      `${this.url}/twilio_editions/${editionId}/agents/${assignmentId}`
    );
  }

  getTwilioQueues() {
    return axios.get(`${this.url}/twilio_queues`);
  }

  // Agent identity CRUD
  getTwilioAgents() {
    return axios.get(`${this.url}/twilio_agents`);
  }

  getTwilioAgent(agentId) {
    return axios.get(`${this.url}/twilio_agents/${agentId}`);
  }

  addTwilioAgent(data) {
    return axios.post(`${this.url}/twilio_agents`, data);
  }

  updateTwilioAgent(agentId, data) {
    return axios.put(`${this.url}/twilio_agents/${agentId}`, data);
  }

  deleteTwilioAgent(agentId) {
    return axios.delete(`${this.url}/twilio_agents/${agentId}`);
  }

  // Agent assignment CRUD
  getAgentAssignments(agentId) {
    return axios.get(`${this.url}/twilio_agents/${agentId}/assignments`);
  }

  addAgentAssignment(agentId, data) {
    return axios.post(
      `${this.url}/twilio_agents/${agentId}/assignments`,
      data
    );
  }

  updateAgentAssignment(agentId, assignmentId, data) {
    return axios.put(
      `${this.url}/twilio_agents/${agentId}/assignments/${assignmentId}`,
      data
    );
  }

  deleteAgentAssignment(agentId, assignmentId) {
    return axios.delete(
      `${this.url}/twilio_agents/${agentId}/assignments/${assignmentId}`
    );
  }

  // Twilio Opening Hours
  getOpeningHours() {
    return axios.get(`${this.url}/twilio_opening_hours`);
  }

  getQueueHours(queueName) {
    return axios.get(`${this.url}/twilio_opening_hours/queue/${queueName}`);
  }

  updateQueueHours(queueName, data) {
    return axios.put(
      `${this.url}/twilio_opening_hours/queue/${queueName}`,
      data
    );
  }

  getEditionHours(editionId) {
    return axios.get(
      `${this.url}/twilio_opening_hours/edition/${editionId}`
    );
  }

  updateEditionHours(editionId, data) {
    return axios.put(
      `${this.url}/twilio_opening_hours/edition/${editionId}`,
      data
    );
  }

  deleteEditionHours(editionId) {
    return axios.delete(
      `${this.url}/twilio_opening_hours/edition/${editionId}`
    );
  }
}

export default new VoltAPI();
