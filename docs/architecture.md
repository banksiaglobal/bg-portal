# Portal — management portal carcass

Server-rendered, page-per-class portal on top of `Banksia.Bloom`. No SPA, no
frontend build for extensions: every screen and every extension ships as
ObjectScript and renders at request time.

## Layout

| Class | Role |
|---|---|
| `Portal.Page` | Base page. `RESOURCE` (IRIS resource checked before render), `PAGEID` (target for extension columns/actions), `TITLE`. Generic `InvokeAction` WebMethod dispatches extension actions and writes `^Portal.Audit`. |
| `Portal.Layout` | Shell: top bar (instance name, LIVE/TEST/DEV, user menu), collapsible sidebar, main outlet, footer. All content comes from the registry. |
| `Portal.Context` | Instance identity: `^Portal.Config("SYSTEM_NAME")` / `^Portal.Config("SYSTEM_TYPE")`, version. |
| `Portal.Ext.Contribution` | Abstract base for extensions. Hooks: `NavItems`, `TopBarItems`, `UserMenuItems`, `FooterItems`, `Columns(pageId)`, `Actions(pageId)`. Item shapes are documented on the class. |
| `Portal.Ext.Registry` | Discovers subclasses, filters by API version / enabled flag / resource, isolates failures, detects id collisions, sorts. `?safemode=1` loads nothing. |
| `Portal.Core` | The built-in contribution (nav, user menu, footer, web-app actions). Core and site extensions use the same path. |
| `Portal.Ext.Example` | Reference extension: a computed column and a navigate action on the web-app list. Disable or delete once real ones exist. |
| `Portal.Extensions` | Admin screen: installed extensions, enable/disable, last errors, collisions. |
| `Portal.Api.Service` | Abstract base for domain adapters over `%Api.Admin.Endpoints.*`: drives an endpoint in-process (`Invoke`), whitelists request fields against its schema (`SchemaSubset`), and provides `Get`/`Delete`/`Enable`/`Disable`. Pages never touch `%Api.Admin.*` or `Security.*`. |
| `Portal.WebApp.Service` | `Portal.Api.Service` over `%Api.Admin.Endpoints.WebApp.App`; adds `List` and `Save`. |
| `Portal.WebApp.List` / `Edit` | First migrated screens. |
| `Portal.User.Service` | `Portal.Api.Service` over `%Api.Admin.Endpoints.Security.User`; adds `List`, `Save` (POST for new, PUT for existing), `ChangePassword`, and `RoleNames` from `%Api.Admin.Endpoints.Security.Role`. |
| `Portal.User.List` / `Edit` | User list and edit screens; page ids `user.list` / `user.edit`. |
| `Portal.Role.Service` | `Portal.Api.Service` over `%Api.Admin.Endpoints.Security.Role`; adds `List`, `Save` (PUT upserts), `Members` (owner list, type 10) and `Names`. |
| `Portal.Role.List` / `Edit` | Role list and edit (granted roles, resource/permission table, read-only members); page ids `role.list` / `role.edit`. |
| `Portal.Resource.Service` | `Portal.Api.Service` over `%Api.Admin.Endpoints.Security.Resource`; adds `List`, `Find`, `Save`, `Names`, and overrides `Get` (endpoint returns `{}` not an error for a missing name) and `Delete` (enforces `AllowDelete`, which the endpoint ignores). The empty-`PublicPermission` cases go to `Security.Resources` directly because the endpoint cannot express them. |
| `Portal.Resource.List` / `Edit` | Resource list and edit; page ids `resource.list` / `resource.edit`. |
| `Portal.WebSession.Service` | `Portal.Api.Service` over `%Api.Admin.Endpoints.WebSession` (`IDPARAM = "id"`, rows keyed on `ID`); `List` and `EndSession`. No GET or edit. |
| `Portal.WebSession.List` | Web session list with an End-session action; page id `websession.list`. Resource `%Admin_Operate`. |
| `Portal.Process.Service` | `Portal.Api.Service` over `%Api.Admin.Endpoints.Process` (`IDPARAM = "id"`, rows keyed on `Pid`); adds `List`, `Get`, `Suspend`, `Resume`, `Terminate` and `Broadcast`. No create/edit. |
| `Portal.Process.List` / `Detail` | Process list (multi-select + broadcast dialog) and read-only detail with variables; page ids `process.list` / `process.detail`. Resource `%Admin_Operate`. |

## Adding a page

For a List + Edit screen over an `%Api.Admin` endpoint, follow
[`adding-a-management-screen.md`](adding-a-management-screen.md).

```objectscript
Class My.Portal.Thing Extends Portal.Page
{
Parameter RESOURCE = "%Admin_Manage";
Parameter PAGEID = "my.thing";
XData Template [ MimeType = text/vue ] { <div>...</div> }
}
```

The class must live under the `Portal` package (or its own package with a
`<pkg>.Layout` that reuses `Portal.Layout`'s content) for the shell to wrap it.
Add a nav entry through a contribution, not by editing `Portal.Core`.

## Adding an extension

```objectscript
Class My.Portal.Ext Extends Portal.Ext.Contribution
{
ClassMethod Columns(pageId As %String) As %DynamicArray
{
    return:pageId'="webapp.list" []
    return [{"key": "Owner", "label": "Owner", "order": 35, "class": "My.Portal.Ext", "method": "Owner"}]
}
ClassMethod Owner(row As %DynamicObject) As %String { return $get(^MyOwners(row.Name)) }
}
```

Compile; it is discovered on the next request. Extension columns are computed
server-side per row; server actions receive the row and return a `%Status`.

## State

- `^Portal.Ext("disabled"|"error"|"collision"|"incompatible", ...)` — registry state, visible on `Portal.Extensions.cls`
- `^Portal.Audit(n) = $lb($h, user, pageId, actionId, contributingClass, rowJson)`
