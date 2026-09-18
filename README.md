# IRIS Portal

A page-per-class management portal for InterSystems IRIS. Server-rendered ObjectScript
pages carrying Vue templates, a thin `Banksia.Bloom` runtime, and a declarative
extension registry. No SPA, no client router, no frontend build for extensions.

See [`docs/architecture.md`](docs/architecture.md) for the architecture,
how to add a page and how to write an extension.

## Layout

```
src/cls/Banksia/Bloom/   Page + Component runtime (ObjectScript class -> Vue instance, WebMethod proxying)
src/cls/Portal/          the portal: shell, registry, core contribution, screens
src/vue/                 frontend entry (PrimeVue, Tailwind, the few global Vue components)
src/csp/portal/          CSP application root; ui/ is the build output (ignored)
module.xml               ZPM module: packages + /csp/portal web application
```

## Run locally

```bash
docker compose up -d --build     # IRIS on http://localhost:59873, SuperServer 59872
nvm use && npm ci
npm run build-only               # or `npm run watch` during development
```

Open <http://localhost:59873/csp/portal/Portal.Home.cls> and log in with an IRIS
account holding `%Admin_Secure` (e.g. `_SYSTEM` / `SYS` in the dev container).

To reload classes after editing without rebuilding the image:

```bash
docker compose exec iris iris session IRIS -U USER \
  '##class(%SYSTEM.OBJ).LoadDir("/home/irisowner/src/cls","ck",,1)'
```

## Instance identity

Every page shows which system it is acting on. Set once per instance:

```objectscript
set ^Portal.Config("SYSTEM_NAME") = "Claims prod-eu-1"
set ^Portal.Config("SYSTEM_TYPE") = "LIVE"   ; LIVE | TEST | DEV (default DEV)
```

## Development notes

- Pages extend `Portal.Page`; the shell (`Portal.Layout`) wraps every class under the
  `Portal` package automatically.
- `ClientMethod`s are emitted into the Vue `methods` block; they are `async` only when
  the body contains `await`, so plain helpers can be used in template expressions.
- Anything referenced from an XData template as a component must be registered in
  `src/vue/components.ts` (PrimeVue components are registered in `primeVue.ts`).
- Tailwind scans `src/cls` for class names, so a new utility class in a template
  needs a rebuild of the frontend bundle.
