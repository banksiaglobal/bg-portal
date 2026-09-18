import ConfirmDialog from './components/ConfirmDialog.vue';
import Tooltip from 'primevue/tooltip';
import type { App } from 'vue';

// Components referenced from XData templates must be registered globally here.
export default function useComponents(app: App<Element>) {
  app.component('ConfirmDialog', ConfirmDialog);
  app.directive('tooltip', Tooltip);
}
