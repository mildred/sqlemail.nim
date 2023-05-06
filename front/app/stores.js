import { writable } from './utils/store.js';
export * from './utils/store.js';

const prefix = 'disputatio'

export const session = writable({
  default_value: true,
  ...JSON.parse(sessionStorage.getItem(`${prefix}.session`) || '{}')
});

