/* eslint-disable vue/no-reserved-component-names */
/* eslint-disable vue/multi-word-component-names */
import PrimeVue from 'primevue/config';
import Aura from '@primevue/themes/aura';
import { definePreset } from '@primevue/themes';
import Button from 'primevue/button';
import DataTable from 'primevue/datatable';
import Column from 'primevue/column';
import InputText from 'primevue/inputtext';
import AutoComplete from 'primevue/autocomplete';
import FloatLabel from 'primevue/floatlabel';
import IconField from 'primevue/iconfield';
import InputIcon from 'primevue/inputicon';
import OverlayPanel from 'primevue/overlaypanel';
import Tabs from 'primevue/tabs';
import TabList from 'primevue/tablist';
import Tab from 'primevue/tab';
import TabPanels from 'primevue/tabpanels';
import TabPanel from 'primevue/tabpanel';
import BlockUI from 'primevue/blockui';
import { Card, DatePicker, Fluid, InputSwitch, ToggleSwitch, MultiSelect, Paginator, Password, Select, SelectButton, Sidebar, Tag, Textarea, Dialog, Menubar, Menu, Drawer } from 'primevue';
import type { App } from 'vue';

export default function usePrimeVue(app: App<Element>) {
  const MyPreset = definePreset(Aura, {
    semantic: {
      primary: {
        50: '#f6f7fb',
        100: '#d3d8eb',
        200: '#b0b8dc',
        300: '#8d99cc',
        400: '#6a7abd',
        500: '#475bad',
        600: '#3c4d93',
        700: '#324079',
        800: '#27325f',
        900: '#1c2445',
        950: '#12172b',
      },
      colorScheme: {
        light: {
          text: {
            color: '{surface.950}',
          },
          formField: {
            color: '{surface.950}',
            disabledBackground: '{surface.100}',
          },
        },
        dark: {
          text: {
            color: '{surface.500}',
          },
        },
      },
    },
  });

  app.use(PrimeVue, {
    theme: {
      preset: MyPreset,
      options: {
        darkModeSelector: '.app-dark',
      },
    },
  });

  app.component('Button', Button);
  app.component('PButton', Button);
  app.component('DataTable', DataTable);
  app.component('DatePicker', DatePicker);
  app.component('Column', Column);
  app.component('InputText', InputText);
  app.component('AutoComplete', AutoComplete);
  app.component('Textarea', Textarea);
  app.component('Password', Password);
  app.component('FloatLabel', FloatLabel);
  app.component('IconField', IconField);
  app.component('InputIcon', InputIcon);
  app.component('InputSwitch', InputSwitch);
  app.component('ToggleSwitch', ToggleSwitch);
  app.component('Fluid', Fluid);
  app.component('Tabs', Tabs);
  app.component('Tab', Tab);
  app.component('Tag', Tag);
  app.component('TabPanel', TabPanel);
  app.component('TabPanels', TabPanels);
  app.component('TabList', TabList);
  app.component('Sidebar', Sidebar);
  app.component('Select', Select);
  app.component('SelectButton', SelectButton);
  app.component('MultiSelect', MultiSelect);
  app.component('Card', Card);
  app.component('OverlayPanel', OverlayPanel);
  app.component('Dialog', Dialog);
  app.component('Menu', Menu);
  app.component('Menubar', Menubar);
  app.component('Drawer', Drawer);
  app.component('Paginator', Paginator);
  app.component('BlockUI', BlockUI);

}
