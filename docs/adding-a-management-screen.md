# Adding a management screen over an `%Api.Admin` endpoint

Recipe for a new List + Edit pair (like `Portal.WebApp.*` and `Portal.User.*`)
backed by one of InterSystems' `%Api.Admin.Endpoints.*` classes. Follow it top to
bottom; every step names the reference implementation to copy from.

## 0. Ground rules

- Pages never call `%Api.Admin.*` or `Security.*`. All backend access goes through
  one `Portal.<Thing>.Service` class extending `Portal.Api.Service`.
- The endpoint is driven **in-process**, not over HTTP. `Portal.Api.Service.Invoke`
  does what the REST dispatcher (`%Api.Admin.Dispatch.v1`) would: instantiate the
  endpoint with a request type, set its `name` query parameter, validate, `Run`.
  `IsRunningAsync = 1` turns the endpoint's `SetRespStatus`/`SetRespHeader` into
  no-ops so a 404 inside it cannot clobber the portal page's own `%response`.
- Every service method that touches an endpoint starts with
  `new $namespace  set $namespace = "%SYS"`.

## 1. Read the endpoint class first

Open `%Api.Admin.Endpoints.<X>` (they are `Hidden`; find them via
`%Dictionary.ClassDefinitionQuery:SubclassOf("%Api.Admin.Endpoint")`) and note:

| Look for | Why it matters |
|---|---|
| `ValidateQueryParams` | Which types need `name`. LIST usually does not. Some endpoints key on a different parameter (`Process` uses `id`) — set `IDPARAM` on the service. |
| `RunList` | **List rows have their own column set**, typically a subset of the detail with *different spellings* (`Namespace` in list vs `NameSpace` in get, `Type` as display text). Decide whether the list page can live with it or must merge `Get()` per row (`Portal.WebApp.Service.List` merges; `Portal.User.Service.List` does not). |
| `RunPut` / `RunPost` | Create semantics differ per endpoint. WebApp: PUT upserts. User: PUT modifies an existing user only, POST creates with `{ "User": {...}, "Password": "" }`. |
| `RequestBodySchema()` / `Schema()` | The whitelist of fields and their JSON types. The name of this method is not uniform — set `SCHEMAMETHOD` accordingly. |
| `ValidateRequest` | `%Api.Admin.Util.RequestValidator` **rejects unknown fields** (`ERROR #40307`), and may add required ones for new objects (`#40301`). Always pass the body through `SchemaSubset` first. |
| Extra `Parameter TYPE… As INTEGER` and an overridden `Run` | Endpoint-specific operations (e.g. user `TYPECHANGEPWD = 10`). |
| `ObjToJson` | The get shape. It never includes `Name`; `Portal.Api.Service.Get` adds it. Dates come out as `YYYY-MM-DD` via `ZDate3` and are accepted back in the same form. |
| `ResourcesOR` | The IRIS resource the pages must declare in `RESOURCE`. |
| `SetRespStatus(..#HTTP4xx…)` **without** setting `sc` | With `IsRunningAsync` that status is a no-op, so the call looks successful and does nothing. `Resource` does this for an invalid/empty `PublicPermission` and for a missing name on GET (`{}` with OK). Probe those paths and guard them in the service. |
| `RunDelete` | Whether it honours the list's `AllowDelete`-style flags. `Resource` deletes system resources; the service must refuse. |

Not every endpoint is a List + Edit pair. `Process` has no PUT/POST at all — only
LIST, GET and operations (suspend/resume/terminate/broadcast). For those, the second
page is a read-only `Detail` (`Portal.Process.Detail`) whose operations are
`WebMethod`s, and the service exposes the operations as row-taking methods for
the registry. Copy from `Portal.Process.*` rather than `Portal.User.*` in that case.

Base type numbers (`%Api.Admin.Endpoint`): 0 list, 1 get, 2 put, 3 delete,
4 patch, 5 post, 6 head. They are exposed as `TYPELIST`, `TYPEGET`, … on
`Portal.Api.Service`.

## 2. Probe it from a terminal

Do this before writing the service; it tells you the real list/get shapes.

```objectscript
zn "%SYS"
// LIST — note: sc must be initialised, RunQuery reads it
s sc=1,e=##class(%Api.Admin.Endpoints.Security.User).%New(0) s e.IsRunningAsync=1
d e.ValidateQueryParams() s r=e.Run(.sc,{}) w +sc," ",r.%Size(),! w r.%Get(0).%ToJSON(),!
// GET
s sc=1,e=##class(%Api.Admin.Endpoints.Security.User).%New(1) s e.IsRunningAsync=1
d e.SaveOneQueryParam("name","_SYSTEM") d e.ValidateQueryParams() s r=e.Run(.sc,{}) w +sc,! w r.%ToJSON(),!
```

`$$$ISOK`/`$$$ISERR` are not available in the terminal; use `+sc` and
`$system.Status.GetErrorText(sc)`. A not-found GET returns an error status
(`sc` from `Exists`), not an empty OK object.

## 3. Write `Portal.<Thing>.Service`

Copy `src/cls/Portal/User/Service.cls`.

```objectscript
Class Portal.Thing.Service Extends Portal.Api.Service
{
Parameter ENDPOINT = "%Api.Admin.Endpoints.<X>";
Parameter SCHEMAMETHOD = "Schema";          // only if the endpoint does not use RequestBodySchema
Parameter IDPARAM = "id";                   // only if the endpoint does not use `name`
ClassMethod List() As %DynamicArray { ... }  // ..Invoke(..#TYPELIST, "", {}, .sc)
ClassMethod Save(obj As %DynamicObject) As %Status { ... }
}
```

Inherited and normally sufficient: `Get(name)` (returns `""` when missing),
`Delete(row)`, `Enable(row)`, `Disable(row)`, `SetEnabled`, `SchemaSubset`,
`Invoke`, `InvokeEndpoint(class, …)` for lookups on a neighbouring endpoint
(see `RoleNames`).

`Save` conventions the pages rely on:
- takes the whole edit-page JSON (which includes `Name`, display-only keys, and for
  new users `Password`); `SchemaSubset` strips what the validator would reject;
- returns a `%Status`; validation messages from the endpoint are already readable
  (`Field 'NameSpace' is required in the request body.`).

Action methods used from the registry (`Delete`, `Enable`, `Disable`, anything
custom) take the **row object** and return `%Status`.

Test the whole lifecycle in the terminal (`zn "USER"` after `LoadDir`): create,
get, modify, disable/enable, delete, delete again (expect a not-found error).
Do not `$system.Security.Login` as the test user inside the same session — the
following calls run as that user and fail with `<PROTECT>` on `zn "%SYS"`.

## 4. Write `Portal.<Thing>.List`

Extend `Portal.ListPage`; copy `src/cls/Portal/User/List.cls` (~35 lines). Supply:

- `PAGEID` (`thing.list`), `TITLE`, `SUBTITLE`, `RESOURCE` (from `ResourcesOR`);
- `CREATEURL` / `NEWLABEL` for the "New" button (omit `CREATEURL` when there is no create);
- `ROWURL` with `{Field}` placeholders for the row click (omit for no detail page);
- `ROWKEY` when rows are not keyed on `Name` (`Pid`, `ID`);
- `CONFIRMNOUN` — the suffix of the confirm dialog title (`" user"`);
- `CoreColumns()` — keys must match the **list** row shape from step 2. Column
  `type` may be `boolean` (Tag), `tag` (Tag with a `severities` map by value) or `mono`;
- `Rows()` — `##class(Portal.Thing.Service).List()`.

Everything else (global filter, extension columns, actions, confirm, reload) is
inherited. For operations that need extra UI, add `XData ToolbarTemplate` (header
buttons) and `XData ExtraTemplate` (dialogs) plus the `WebMethod`/`ClientMethod`s
they call — `Portal.Process.List` does this for broadcast, together with
`SELECTION = "multiple"`, `SHOWREFRESH` and `HINT`. Override `describeRow(row)`
when the confirm message should say more than the row key.

## 5. Write `Portal.<Thing>.Edit`

Extend `Portal.EditPage`; copy `src/cls/Portal/WebApp/Edit.cls` (~70 lines). Supply:

- `PAGEID`, `TITLE`, `RESOURCE`, `NOUN` ("New <noun>" heading), `LISTURL`;
- `Fields()` — one descriptor per input:
  `{key, label, type, order, section, colSpan, placeholder, help, options, clearable, when, disabledIf, newOnly, existingOnly}`.
  Types: `text` (default), `number`, `password`, `date` (bound as the endpoint's
  `YYYY-MM-DD` string), `textarea`, `select`, `multiselect`, `toggle`, `perms`
  (R/W/U string). `options` is an array or the name of a page property holding one.
  Toggles are gathered into a row at the end of their section; `section` groups
  fields into a titled card;
- `Load(name)` — `Service.Get(name)`, returning `""` when missing (the base then
  switches to create mode and uses `Defaults()`, which **must contain every key a
  field binds**, otherwise Vue renders `undefined`);
- `Save(obj)` — `Service.Save(obj)`; returns a `%Status`;
- `OnLoad()` — populate lookup properties (`namespaces`, `roles`) that `options` name;
- `Subtitle()` — text under the heading in edit mode.

The `Name` field (`NAMEFIELD`) is read-only once the object exists. Save goes
through the inherited `SaveObject` WebMethod; on success the browser returns to
`LISTURL`. Extra operations (change password) get their own `WebMethod` + button
in `XData ExtraTemplate`; so do sub-tables the descriptors cannot express
(`Portal.Role.Edit`'s resource/permission table). Do not overload Save.

- `ClientMethod`s become Vue `methods`; they are made `async` automatically when
  the body contains `await`. Do not name one the same as a server method ignoring
  case (`Save`/`save` collide in ObjectScript).
- Available components: PrimeVue set registered in `src/vue/primeVue.ts`
  (`InputText`, `Password`, `Select`, `MultiSelect`, `ToggleSwitch`, `DatePicker`,
  `Textarea`, `Card`, `Tag`, `DataTable`, …; `Button` is registered as `PButton`)
  plus `ConfirmDialog` from `src/vue/components.ts`.

Extensions can add fields to the page through the `page.<pageId>.fields` slot;
the base seeds and persists them through the contributing class, so `Save` never sees them.

## 6. Wire it into the shell

`Portal.Core.Contribute(slot)`:
- `shell.nav` — add `{"id": "security.things", "label": …, "group": …, "url": "Portal.Thing.List.cls", "resource": …}` to `Nav()`.
- `page.thing.list.actions` — return a `ThingActions()` array: `edit` (kind
  `navigate`, `url` with `{Name}`), `disable`/`enable` (`when: "row.Enabled"` /
  `"!row.Enabled"`), `delete` (`confirm: true`). `class`/`method` point at the
  service's row-taking methods.

Site extensions may add more via `Portal.Ext.Contribution` using the same page ids.

## 7. Dev loop

```bash
docker compose exec iris iris session IRIS -U USER \
  '##class(%SYSTEM.OBJ).LoadDir("/home/irisowner/src/cls","ck",,1)'
npm run build-only     # templates with new Tailwind classes need a bundle rebuild
curl -s -o /dev/null -w "%{http_code}\n" -u _SYSTEM:SYS http://localhost:59873/csp/portal/Portal.Thing.List.cls
```

Then open the page in a browser and run one create → edit → disable → delete
round trip; the terminal test in step 3 does not exercise the templates.

## 8. Document

Add the new classes to the table in `architecture.md`.
