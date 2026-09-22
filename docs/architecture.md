# Portal — management portal carcass

Server-rendered, page-per-class portal on top of `Banksia.Bloom`. No SPA, no
frontend build for extensions: every screen and every extension ships as
ObjectScript and renders at request time.

## Layout

| Class | Role |
|---|---|
| `Portal.Page` | Base page. `RESOURCE` (IRIS resource checked before render), `PAGEID` (names the page's slots), `TITLE`. Generic `InvokeAction` WebMethod dispatches extension actions and writes `^Portal.Audit`. `<ext-slot name="…" ctx="…">` in a template is expanded into widget cards at emit time; `WidgetSlots()` discovers those tags, `LoadWidgets()` fills `widgets` keyed by slot id, `ExtraComponents()` tells the Bloom emitter which extension components to ship. Client side: `evalWhen` (the safe `when` evaluator), `passes`, `slotWidgets`, `cmp`. |
| `Portal.Layout` | Shell: top bar (instance name, LIVE/TEST/DEV, user menu), collapsible sidebar, main outlet, footer. All content comes from the registry. |
| `Portal.Context` | Instance identity: `^Portal.Config("SYSTEM_NAME")` / `^Portal.Config("SYSTEM_TYPE")`, version. |
| `Portal.ListPage` | Abstract list screen: filterable/paginated table, extension columns computed per row (or rendered by a component), row actions with confirm, bulk actions on the selection (`InvokeBulkAction`, audit of the selected keys), `ToolbarTemplate`/`ExtraTemplate` XData slots, `<ext-slot name="footer">`. A subclass supplies `CoreColumns()`, `Rows()` and parameters (`CREATEURL`, `ROWURL`, `ROWKEY`, `CONFIRMNOUN`, `SELECTION`, `SHOWREFRESH`, `HINT`). |
| `Portal.EditPage` | Abstract create/edit screen driven by field descriptors (`text`, `password`, `select`, `multiselect`, `toggle`, `date`, `textarea`, `number`, `perms`), grouped into sectioned cards. A subclass supplies `Fields()`, `Load(name)`, `Defaults()`, `Save(obj)` and optionally `OnLoad()`, `Subtitle()`, `ExtraTemplate`. Extension fields from `page.<PAGEID>.fields` are merged in and persisted through the contributing class; `<ext-slot name="sidebar">`. |
| `Portal.Ext.Contribution` | Abstract base for extensions. Manifest parameters (`ID`, `NAME`, `VERSION`, `PUBLISHER`, `HOMEPAGE`, `REQUIRES`) and `Manifest()`; lifecycle hooks `OnInstall`, `OnUpgrade`, `OnEnable`, `OnDisable`, `OnUninstall`. One contribution hook, `Contribute(slot)`, over slot ids `shell.nav|topbar|user-menu|footer` and `page.<pageId>.columns|actions|bulk-actions|fields|widgets.<name>`. Every item may carry a display-only `when` expression. Item shapes are documented on the class and in [`writing-an-extension.md`](writing-an-extension.md). |
| `Portal.Ext.Registry` | Discovers subclasses and reconciles lifecycle state (`Sync`: `OnInstall`/`OnUpgrade`, pruning of vanished classes; `SetEnabled` → `OnEnable`/`OnDisable` with rollback; `Uninstall`/`Reinstall`); `ModuleFor` maps a class to its installed ZPM module; `Collect(slot)` runs `Contribute(slot)` on every contribution, validates every item against `Portal.Ext.Schema` (invalid items dropped and reported, unknown keys warned), applies `replaces`/`hide` overrides, filters by API version / enabled flag / resource, isolates failures, detects id collisions (diagnostics keyed by slot), sorts; `FindItem(slot, id)` for server dispatch; `ValidComponent`. Discovery runs once per request (memoised in `%PortalExt`) and the validated raw hook output is cached in `^Portal.Ext("cache", fingerprint, class, slot)` under a fingerprint of the contribution set (classes + compile times + disabled/retired state + `APIVERSION`), so a warm render calls no hook; `ClearCache()`, `?nocache=1`, `^Portal.Config("EXT_CACHE") = 0`. `?safemode=1` loads nothing. |
| `Portal.Ext.Schema` | Item schemas per slot kind (`items`, `columns`, `actions`, `bulk-actions`, `fields`, `widgets`) as `%DynamicObject` descriptors: required and allowed keys, value types, enumerations (`kind`, field `type`, `severity`, widget `width`), conditional requirements (`kind: server` needs `class`/`method`), a syntax check of `when`. `Validate(slot, item)` is what the registry runs; `ForSlot(slot)` feeds the reference. |
| `Portal.Ext.Slots` | The extension-points list generated from code: shell slots, per-page slots of every concrete `Portal.Page` in any package (columns/actions/bulk-actions on lists, fields on edit pages) and every `<ext-slot>` a page declares, each with its item schema; `WithCounts()` adds the number of contributed items; `Markdown()` renders the reference as text. |
| `Portal.Core` | The built-in contribution (nav, user menu, footer, the core row actions), written against `Contribute(slot)` with `when` — the reference for extension authors. Core and site extensions use the same path. |
| `PortalExt.Example.*` | Reference extension, **not part of core**: its own ZPM module in [`extensions/portal-ext-example/`](../extensions/portal-ext-example/). A page of its own (`HelloPage`, with its sidebar entry under "Examples"), a computed column with a custom cell component, a navigate action and a bulk action on the web-app list, a note field and a summary sidebar on the user edit page, a live user-count widget on the home page, and every lifecycle hook leaving a marker in `^PortalExt.Example`. |
| `Portal.Extensions` | Admin screen: installed extensions with manifest, ZPM module, required resources (flagged when the viewer lacks one), install date, lifecycle and slot errors (red) and validation warnings (amber), enable/disable, Uninstall (retire) / Reinstall, overrides, collisions, "Clear diagnostics" and "Clear cache", and the "Extension points" reference (every slot with its item count; expanded, the item keys with types, enumerations and an example). |
| `Portal.Api.Service` | Abstract base for domain adapters over `%Api.Admin.Endpoints.*`: drives an endpoint in-process (`Invoke`), whitelists request fields against its schema (`SchemaSubset`), and provides `Get`/`Delete`/`Enable`/`Disable`. Pages never touch `%Api.Admin.*` or `Security.*`. |
| `Portal.WebApp.Service` | `Portal.Api.Service` over `%Api.Admin.Endpoints.WebApp.App`; adds `List` and `Save`. |
| `Portal.WebApp.List` / `Edit` | First migrated screens; `Portal.ListPage` / `Portal.EditPage` subclasses. |
| `Portal.User.Service` | `Portal.Api.Service` over `%Api.Admin.Endpoints.Security.User`; adds `List`, `Save` (POST for new, PUT for existing), `ChangePassword`, and `RoleNames` from `%Api.Admin.Endpoints.Security.Role`. |
| `Portal.User.List` / `Edit` | User list and edit screens; page ids `user.list` / `user.edit`. Edit adds a change-password card through `ExtraTemplate`. |
| `Portal.Role.Service` | `Portal.Api.Service` over `%Api.Admin.Endpoints.Security.Role`; adds `List`, `Save` (PUT upserts), `Members` (owner list, type 10) and `Names`. |
| `Portal.Role.List` / `Edit` | Role list and edit (granted roles, resource/permission table, read-only members); page ids `role.list` / `role.edit`. The resource table and members live in `ExtraTemplate`. |
| `Portal.Resource.Service` | `Portal.Api.Service` over `%Api.Admin.Endpoints.Security.Resource`; adds `List`, `Find`, `Save`, `Names`, and overrides `Get` (endpoint returns `{}` not an error for a missing name) and `Delete` (enforces `AllowDelete`, which the endpoint ignores). The empty-`PublicPermission` cases go to `Security.Resources` directly because the endpoint cannot express them. |
| `Portal.Resource.List` / `Edit` | Resource list and edit; page ids `resource.list` / `resource.edit`. |
| `Portal.WebSession.Service` | `Portal.Api.Service` over `%Api.Admin.Endpoints.WebSession` (`IDPARAM = "id"`, rows keyed on `ID`); `List` and `EndSession`. No GET or edit. |
| `Portal.WebSession.List` | Web session list with an End-session action; page id `websession.list`. Resource `%Admin_Operate`. |
| `Portal.Process.Service` | `Portal.Api.Service` over `%Api.Admin.Endpoints.Process` (`IDPARAM = "id"`, rows keyed on `Pid`); adds `List`, `Get`, `Suspend`, `Resume`, `Terminate` and `Broadcast`. No create/edit. |
| `Portal.Process.List` / `Detail` | Process list (`SELECTION = "multiple"`, broadcast button/dialog in `ToolbarTemplate`/`ExtraTemplate`) and read-only detail with variables; page ids `process.list` / `process.detail`. `Detail` stays on `Portal.Page`: it is a read-only dashboard, not a form. Resource `%Admin_Operate`. |

## Adding a page

For a List + Edit screen over an `%Api.Admin` endpoint, follow
[`adding-a-management-screen.md`](adding-a-management-screen.md). A list is a
`Portal.ListPage` subclass with columns and a row source; an edit page is a
`Portal.EditPage` subclass with field descriptors and load/save methods:

```objectscript
Class My.Portal.Thing.List Extends Portal.ListPage
{
Parameter RESOURCE = "%Admin_Manage";
Parameter PAGEID = "my.thing.list";
Parameter TITLE = "Things";
Parameter CREATEURL = "My.Portal.Thing.Edit.cls";
Parameter ROWURL = "My.Portal.Thing.Edit.cls?name={Name}";
ClassMethod CoreColumns() As %DynamicArray { return [{"key": "Name", "label": "Name", "sortable": true, "order": 10}] }
ClassMethod Rows() As %DynamicArray { return ##class(My.Portal.Thing.Service).List() }
}

Class My.Portal.Thing.Edit Extends Portal.EditPage
{
Parameter RESOURCE = "%Admin_Manage";
Parameter PAGEID = "my.thing.edit";
Parameter NOUN = "thing";
Parameter LISTURL = "My.Portal.Thing.List.cls";
Method Fields() As %DynamicArray { return [{"key": "Name", "label": "Name", "order": 10}, {"key": "Enabled", "label": "Enabled", "type": "toggle", "order": 20}] }
ClassMethod Load(name As %String) As %DynamicObject { return ##class(My.Portal.Thing.Service).Get(name) }
ClassMethod Defaults() As %DynamicObject { return {"Name": "", "Enabled": true} }
ClassMethod Save(obj As %DynamicObject) As %Status { return ##class(My.Portal.Thing.Service).Save(obj) }
}
```

Anything the descriptors cannot express (a nested table, a secondary operation with
its own button) goes in an `XData ExtraTemplate` on the subclass, which the base
renders after the form; lists also have `ToolbarTemplate` for extra header buttons.
A free-form page that is neither extends `Portal.Page` directly and supplies its own
`XData Template`.

The class can live in any package: `Portal.Page` names the shell in its `LAYOUT`
parameter (`"Portal.Layout"`; `Banksia.Bloom.Page` takes a comma-separated chain,
outermost first, and falls back to the `<pkg>.Layout` name walk only when it is
empty). Set `PAGEID` so the page gets slots of its own, `RESOURCE` for the access
check, and add the nav entry through a contribution (`shell.nav`), not by editing
`Portal.Core`. An extension module can therefore ship pages next to its contribution;
`PortalExt.Example.HelloPage` is the worked example.

## Adding an extension

Full reference: [`writing-an-extension.md`](writing-an-extension.md).

```objectscript
Class My.Portal.Ext Extends Portal.Ext.Contribution
{
ClassMethod Contribute(slot As %String) As %DynamicArray
{
    return:slot'="page.webapp.list.columns" []
    return [{"key": "Owner", "label": "Owner", "order": 35, "class": "My.Portal.Ext", "method": "Owner"}]
}
ClassMethod Owner(row As %DynamicObject) As %String { return $get(^MyOwners(row.Name)) }
}
```

Compile; it is discovered on the next request. Extension columns are computed
server-side per row; server actions receive the row and return a `%Status`.

`page.<pageId>.fields` adds inputs to a `Portal.EditPage`. The portal never stores the
value: the field names a `class` with a `loader(name)` that seeds it and a
`method(name, value)` that persists it after the page's own save succeeded.
`page.<pageId>.bulk-actions` adds toolbar buttons acting on the selected rows.

`page.<pageId>.widgets.<name>` places a `Banksia.Bloom.Component` in a card wherever
the page declared `<ext-slot name="<name>">` (`dashboard` on home, `footer` on lists,
`sidebar` on edit pages); a column may name a `component` to render its cell. Components ship with the page at request time —
`Banksia.Bloom.Page.OnPage` emits and registers whatever `Portal.Page.ExtraComponents()`
returns — so an extension's client-side rendering needs no frontend build either.

## State

- `^Portal.Ext("installed", class) = $lb(version, $h)` — first seen / last upgraded; `^Portal.Ext("retired", class)` — uninstalled from the screen, ignored until reinstalled
- `^Portal.Ext("override", slot, targetId) = $lb(class, newId)` — item replaced (`newId`) or hidden (`""`) by an extension; refreshed whenever the slot is collected
- `^Portal.Ext("disabled"|"error"|"warning"|"collision"|"incompatible", ...)` — registry state (errors and warnings keyed by slot or lifecycle hook, collisions by slot), visible on `Portal.Extensions.cls`
- `^Portal.Ext("cache", fingerprint, class, slot) = json` — validated raw output of `Contribute(slot)`; one fingerprint generation at a time, dropped by `Sync`/`SetEnabled`/`Uninstall`/`Reinstall`/`ClearCache()`
- `^Portal.Config("EXT_CACHE") = 0` — turns the contribution cache off; `?nocache=1` bypasses it for one request
- `^Portal.Audit(n) = $lb($h, user, pageId, actionId, contributingClass, rowJson)` — for bulk actions the last field is the JSON array of selected row keys
