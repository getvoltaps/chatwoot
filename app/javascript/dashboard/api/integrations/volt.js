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
}

export default new VoltAPI();
