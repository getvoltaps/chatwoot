import { frontendURL } from 'dashboard/helper/URLHelper.js';
import BulkMailPage from './pages/BulkMailPage.vue';

const meta = {
  permissions: ['administrator', 'agent'],
};

export const routes = [
  {
    path: frontendURL('accounts/:accountId/bulk-mail'),
    name: 'bulk_mail_index',
    meta,
    component: BulkMailPage,
  },
];
