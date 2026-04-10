import VoltAPI from 'dashboard/api/integrations/volt';

const state = {
  drafts: {},
  loading: {},
};

const getters = {
  getDraft: $state => conversationId => $state.drafts[conversationId] || null,
  isLoading: $state => conversationId =>
    !!$state.loading[conversationId],
};

const mutations = {
  SET_DRAFT($state, { conversationId, context, draftReply, translated }) {
    $state.drafts = {
      ...$state.drafts,
      [conversationId]: { context, draftReply, translated },
    };
    const { [conversationId]: _, ...rest } = $state.loading;
    $state.loading = rest;
  },
  SET_LOADING($state, conversationId) {
    $state.loading = { ...$state.loading, [conversationId]: true };
  },
  CLEAR_DRAFT($state, conversationId) {
    const { [conversationId]: _, ...rest } = $state.drafts;
    $state.drafts = rest;
    const { [conversationId]: __, ...loadingRest } = $state.loading;
    $state.loading = loadingRest;
  },
};

const actions = {
  setDraft({ commit }, { conversation_id: conversationId, context, draft_reply: draftReply, translated }) {
    commit('SET_DRAFT', { conversationId, context, draftReply, translated: !!translated });
  },
  setLoading({ commit }, conversationId) {
    commit('SET_LOADING', conversationId);
  },
  clearDraft({ commit }, conversationId) {
    commit('CLEAR_DRAFT', conversationId);
  },
  async generateDraft({ commit }, { conversationId, agentContext = null } = {}) {
    commit('SET_LOADING', conversationId);
    try {
      await VoltAPI.generateAiDraft(conversationId, agentContext);
    } catch {
      commit('CLEAR_DRAFT', conversationId);
    }
  },
};

export default {
  namespaced: true,
  state,
  getters,
  mutations,
  actions,
};
