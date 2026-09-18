import './assets/main.css';
import 'primeicons/primeicons.css';

import { createApp, type App } from 'vue';
import usePrimeVue from './primeVue';
import useComponents from './components';

// Each page class emits a bloomCreateApp() that builds its own Vue instance (see Banksia.Bloom.Page).
const app: App<Element> = window.bloomCreateApp(createApp);

usePrimeVue(app);
useComponents(app);

app.mount('#appDiv');

// Bridge for WebMethod calls: Bloom proxies ObjectScript ClassMethods through %CSP.Broker hyperevents.
window.serverCall = function (method: string, args: unknown[]) {
  return new Promise(function (resolve) {
    const url = '%25CSP.Broker.cls';
    const req = new XMLHttpRequest();

    let data = 'WARGC=' + (args.length - 1) + '&WEVENT=' + method.replace(/&amp;/, '&');
    for (let i = 1; i < args.length; i++) {
      const arg = args[i];
      if (typeof arg != 'object') {
        const scalar = typeof arg == 'boolean' ? (arg ? 1 : 0) : String(arg);
        data = data + '&WARG_' + i + '=' + encodeURIComponent(scalar);
      } else if (arg != null) {
        let n = 0;
        for (const value of Object.values(arg as Record<string, unknown>)) {
          if (typeof value != 'function') {
            data = data + '&W' + i + '=' + encodeURIComponent(String(value));
            n = n + 1;
          }
        }
        data = data + '&WLIST' + i + '=' + n;
      }
    }

    req.onreadystatechange = function () {
      if (req.readyState != 4) return;
      if (req.status != 200) {
        console.error('Unexpected status code, unable to process HyperEvent: ' + req.statusText + ' (' + req.status + ')');
      }

      let result = req.responseText;
      const lines = result.split('\r\n');
      let ok = 0;
      let len = lines.length;
      if (lines[len - 1] == '') len = len - 1;
      for (let i = 2; i < len; i++) {
        if (lines[i] == '#OK') {
          ok = i;
          break;
        }
      }

      if (ok == 0 || (lines[1] != '#R' && lines[1] != '#V')) {
        console.error('Http object response incomplete or invalid.', ok, lines[1]);
      }

      if (lines[1] == '#R') {
        result = '';
        if (ok + 1 < len) {
          result = lines[ok + 1];
          for (let i = ok + 2; i < len; i++) {
            result = result + '\r\n' + lines[i];
          }
        }
      }

      resolve(result);
    };
    req.open('POST', url, true);
    req.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
    req.send(data);
  });
};
