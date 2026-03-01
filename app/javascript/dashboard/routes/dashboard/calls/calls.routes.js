import { frontendURL } from '../../../helper/URLHelper';

import SettingsWrapper from '../settings/SettingsWrapper.vue';
import Index from './Index.vue';
import EditionDetail from './EditionDetail.vue';
import AgentsIndex from './AgentsIndex.vue';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/calls'),
    component: SettingsWrapper,
    children: [
      {
        path: '',
        name: 'calls_queues',
        meta: { permissions: ['administrator'] },
        component: Index,
      },
      {
        path: 'editions/:editionId',
        name: 'calls_edition',
        meta: { permissions: ['administrator'] },
        component: EditionDetail,
      },
      {
        path: 'agents',
        name: 'calls_agents',
        meta: { permissions: ['administrator'] },
        component: AgentsIndex,
      },
    ],
  },
];
