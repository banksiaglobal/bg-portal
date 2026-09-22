# Writing an extension

An extension is one ObjectScript class extending `Portal.Ext.Contribution`, plus any
`Banksia.Bloom.Component` classes it renders with. Compile it and it is live on the
next request; no frontend build, no registration step. Everything an extension
contributes is declarative data — the portal decides where and whether to render
it, and only runs extension code through the `class`/`method` pairs the extension
names itself.

```objectscript
Class Acme.Portal.Ext Extends Portal.Ext.Contribution
{
Parameter ORDER As INTEGER = 200;      // 100+ for site extensions; core is 0-99
Parameter APIVERSION As INTEGER = 2;   // must match Portal.Ext.Registry.APIVERSION or it is skipped
...
}
```

The reference implementation is the separate module in
[`extensions/portal-ext-example/`](../extensions/portal-ext-example/)
(`PortalExt.Example.Contribution`); it exercises every hook below. `Portal.Extensions.cls`
shows each installed extension with its manifest, lets you switch it off or retire it,
and lists its last errors and any id collisions. `?safemode=1` on any page loads no
extensions at all.

## Manifest

```objectscript
Parameter ID = "com.acme.portal.queue";      // stable id; defaults to the class name
Parameter NAME = "Acme queue";               // display name
Parameter VERSION = "1.2.0";                 // semver; a change triggers OnUpgrade
Parameter PUBLISHER = "Acme";
Parameter HOMEPAGE = "https://acme.example/portal-queue";
Parameter REQUIRES = "%Admin_Operate,%Acme_Queue";   // IRIS resources the extension uses
```

`Manifest()` assembles these with the class doc comment as `description`; override it
to compute values. `REQUIRES` is informational: the Extensions screen shows the
resources as chips, red when the viewing admin lacks one. Enforcement stays per item
(`resource`). When the class belongs to an installed ZPM module the registry attaches
`module: {name, version, source}`.

## Lifecycle

| Hook | When |
|---|---|
| `OnInstall()` | the registry sees the class for the first time (first request after compile, or the module's `Activate` hook) |
| `OnUpgrade(fromVersion)` | `VERSION` differs from the one recorded at install |
| `OnEnable()` / `OnDisable()` | the admin switch on the Extensions screen; a failure leaves the switch where it was |
| `OnUninstall()` | *Uninstall* on the Extensions screen (retires the extension, class stays) or the ZPM module's uninstall hook (code is removed right after) |

All return `%Status`; a failure is recorded in `^Portal.Ext("error", class, "<hook>")`
and shown on the Extensions screen. Use them for what a plain compile cannot do:
create globals, resources or roles, migrate stored data, clean up on the way out.
State is in `^Portal.Ext("installed", class) = $lb(version, $h)`; a retired class is
ignored until *Reinstall*. `##class(Portal.Ext.Registry).Sync()` reconciles everything
and is safe to call any time.

## Packaging as a ZPM module

Ship an extension as its own module under `extensions/<name>/` (convention:
`portal-ext-*`) with a package of its own — never inside `Portal.*`, which is the
core module's resource:

```
extensions/portal-ext-acme/
  module.xml
  src/cls/Acme/Portal/Contribution.cls      the Portal.Ext.Contribution subclass
  src/cls/Acme/Portal/QueueWidget.cls       components, services, pages…
```

```xml
<Module>
  <Name>portal-ext-acme</Name>
  <Version>1.2.0</Version>
  <Packaging>module</Packaging>
  <SourcesRoot>src</SourcesRoot>
  <Dependencies><ModuleReference><Name>portal</Name><Version>0.1.*</Version></ModuleReference></Dependencies>
  <Resource Name="Acme.Portal.PKG"/>
  <Invoke Class="Portal.Ext.Registry" Method="Sync" Phase="Activate" When="After" CheckStatus="true"/>
  <Invoke Class="Portal.Ext.Registry" Method="Uninstall" Phase="Unconfigure" When="Before" CheckStatus="false">
    <Arg>Acme.Portal.Contribution</Arg>
    <Arg>0</Arg>
  </Invoke>
</Module>
```

The two `Invoke`s wire ZPM's lifecycle to the portal's: `Sync` after activation runs
`OnInstall`/`OnUpgrade` immediately, and `Uninstall(class, 0)` before unconfigure runs
`OnUninstall` while the code is still there (the `0` drops state without retiring, so
a later `zpm "load"` installs afresh). Load it in the dev container with
`zpm "load /home/irisowner/extensions/portal-ext-acme"`; `zpm "uninstall portal-ext-acme"`
removes the code.

## Slots and `Contribute(slot)`

The one hook is `Contribute(slot)`: the registry calls it once per slot it is
rendering and you return the items for that slot (or `[]`).

```objectscript
ClassMethod Contribute(slot As %String) As %DynamicArray
{
    return:slot="shell.nav" [{"id": "acme.queue", "label": "Queue", "url": "Acme.Portal.Queue.cls", "group": "Acme", "order": 300}]
    return:slot="page.webapp.list.columns" [{"key": "Owner", "label": "Owner", "order": 35, "class": "Acme.Portal.Ext", "method": "Owner"}]
    return []
}
```

Items are validated (see below), merged across extensions, de-duplicated on `id` (or
`key`) — first contribution wins, later duplicates are reported as collisions —
filtered by `resource` (the user must hold `USE` on it) and `role` (the user must hold
that IRIS role, e.g. `%All`), then sorted by `order`, then
by contribution `ORDER`.

**The authoritative slot list is generated from code**: the "Extension points" card
on `Portal.Extensions.cls` lists every slot on this instance (core pages, extension
pages, every declared `<ext-slot>`) with its item count and, expanded, the item keys
with types, required flags, allowed values and an example. The same reference as text:
`##class(Portal.Ext.Slots).Markdown()`; as data: `Portal.Ext.Slots.Slots()`, each entry
carrying its `schema` from `Portal.Ext.Schema`. The table below is a summary.

| Slot | Where it shows | Item shape |
|---|---|---|
| `shell.nav` | sidebar | `{id*, label*, url*, icon, group, order, resource}` |
| `shell.topbar` | top bar, left of the user menu | `{id*, label*, url*, icon, order, resource}` |
| `shell.user-menu` | user menu | `{id*, label*, url*, icon, order}` |
| `shell.footer` | footer | `{id*, label*, url, order}` |
| `page.<pageId>.columns` | a `Portal.ListPage` table | `{key*, label*, order, sortable, type, severities, class, method, component, when, resource}` |
| `page.<pageId>.actions` | row buttons on a `Portal.ListPage` | `{id*, label*, kind*, order, icon, severity, resource, confirm, when, url, class, method}` |
| `page.<pageId>.bulk-actions` | toolbar buttons on the selection of a `Portal.ListPage` | `{id*, label*, order, icon, severity, resource, confirm, when, class*, method*}` |
| `page.<pageId>.fields` | inputs on a `Portal.EditPage` | `{key*, label*, type, order, section, colSpan, placeholder, help, options, resource, when, newOnly, existingOnly, class, loader, method}` |
| `page.<pageId>.widgets.<name>` | cards in a page's `<ext-slot name="<name>">` | `{id*, component*, order, title, width, when, resource}` |

Page ids in core: `webapp.list/edit`, `user.list/edit`, `role.list/edit`,
`resource.list/edit`, `process.list/detail`, `websession.list`, `home`,
`system.extensions`. A page's id is its `PAGEID` parameter. Built-in widget slots:
`page.home.widgets.dashboard`, `page.<list>.widgets.footer`, `page.<edit>.widgets.sidebar`.

### Validation

Every item a hook returns is checked against the schema of its slot kind
(`Portal.Ext.Schema`) before it is used or cached:

- a missing required key, a wrong value type, a value outside an enumeration
  (`kind`, field `type`, `severity`, widget `width`), a `kind: server` action without
  `class`/`method`, a `kind: navigate` without `url`, or a `when` that does not
  tokenise (unbalanced quotes or parentheses, unknown operators) **drops the item**;
  the first reason is recorded in `^Portal.Ext("error", class, slot)` with a count of
  the rest, and shown in red on the Extensions screen;
- an unknown key is a **warning**: the item is kept, the key is passed through, and
  `^Portal.Ext("warning", class, slot)` shows in amber. `replaces`, `hide`, `when`,
  `resource` and `order` are accepted on every item.

Types are lenient where JSON is: a numeric string is a number, `0`/`1` are booleans.
The `when` check is syntactic only; the evaluator on the client (`Portal.Page.evalWhen`)
still decides what the expression means.

### Caching and the dev loop

The registry caches the validated output of every `Contribute(slot)` under a
fingerprint of the contribution set (the concrete classes with their compile times,
the disabled/retired state and the API version), in
`^Portal.Ext("cache", fingerprint, class, slot)`. Recompiling a contribution changes the
fingerprint, so the next request sees the new output and drops the old generation;
nothing to do in the normal edit-compile-reload loop. Resource filtering, overrides
and sorting are not cached (they depend on the user). A hook that throws is not
cached: it is retried on the next request, so fixing it needs no reset either.

- `?nocache=1` on any page bypasses the cache for that request (like `?safemode=1`).
- `set ^Portal.Config("EXT_CACHE") = 0` turns it off for the instance.
- `##class(Portal.Ext.Registry).ClearCache()`, or "Clear cache" on the Extensions
  screen, drops it; `Sync`, `SetEnabled`, `Uninstall` and `Reinstall` do so too.
  "Clear diagnostics" also clears the cache so every hook is re-validated.

A hook that reads mutable state (a global, a table) must not expect to run on every
request: it runs once per fingerprint. Put per-request values in a widget component
(`%OnNew` runs at every render) or a computed column, not in the item list.

### Overriding and hiding core items

Sometimes an extension must change what core does rather than add to it: route a
delete through an approval, drop a menu entry, swap a column renderer. Two item forms
do that deliberately, so accidental duplicates can stay collisions:

```objectscript
return:slot="page.webapp.list.actions" [
    {"id": "delete", "replaces": "delete", "label": "Delete", "kind": "server", "severity": "danger", "confirm": true,
     "class": "Acme.Portal.Ext", "method": "GuardedDelete", "resource": "%Admin_Secure"}
]
return:slot="shell.user-menu" [{"hide": "classic"}]
```

- `replaces: "<id>"` — the item takes the target's place: same position (its `order`
  and load order, unless the replacer sets `order`), target dropped. It may reuse the
  target's id, which keeps the audit trail readable; `source` shows the extension.
- `{"hide": "<id>"}` — removes the item. For actions and bulk actions this also blocks
  server dispatch: `FindItem` resolves against the post-processed list, so a hidden or
  replaced `delete` cannot be invoked by id.

Precedence when a slot is collected:

1. collect items from every contribution in load order (`ORDER`, then class name);
2. drop id collisions (first wins; the rest are listed on the Extensions screen);
3. apply `replaces` — regardless of load order, so a site extension can replace a
   core item; a second replacer of the same target is a collision; a target that does
   not exist is an error on the extension and the item is kept as a normal item;
4. apply `hide` — unknown ids are errors and change nothing;
5. filter by `resource` — a replacement is subject to its own `resource`; if the
   replacer lacks it the item is simply absent, because the target is already gone
   (fail closed, by design);
6. sort by `order`, then load order.

Overrides are recorded in `^Portal.Ext("override", slot, id)` and listed on the
Extensions screen, with a note on the overriding extension's row.

### `when` expressions

Every item may carry `when`, a small expression evaluated **on the client** to decide
whether the item is shown. It is display only; `resource` remains the security check
and server actions re-check it. Grammar:

```
expr   := or
or     := and ("||" and)*
and    := eq ("&&" eq)*
eq     := rel (("==" | "!=") rel)*
rel    := unary (("<" | "<=" | ">" | ">=") unary)*
unary  := "!" unary | literal | path | "(" or ")"
literal:= 'string' | "string" | number | true | false | null
path   := name ("." name)*
```

Comparisons are strict (`row.Count == '5'` is false when `Count` is a number), except
that `== null` also matches a missing value. Anything else — function calls,
arithmetic, assignment, a syntax error — makes the expression false; nothing is
ever `eval`ed. Names in scope:

| Slot | Scope |
|---|---|
| columns | `rows` (all rows) |
| actions | `row` |
| bulk-actions | `rows` (the selected rows) |
| fields | `obj` (the form object), `isNew` |
| widgets | `ctx` (what the slot passes; see below) |
| all | `user` (login name), `page` (page id) |

Examples: `row.Enabled`, `row.State == 'SUSP'`, `!isNew && obj.Roles.length > 0`,
`rows.length > 1`, `user == '_SYSTEM'`.

### Columns

```objectscript
return:slot="page.webapp.list.columns" [{"key": "Owner", "label": "Owner", "order": 35,
    "class": "Acme.Portal.Ext", "method": "Owner", "component": "Acme.Portal.OwnerCell"}]
...
ClassMethod Owner(row As %DynamicObject) As %String { return $get(^AcmeOwners(row.Name)) }
```

- `class`/`method` compute the value **server-side per row**; a failing method renders
  `#ERR` in that cell and is reported on the Extensions screen.
- `type` picks a built-in renderer: `boolean` (Yes/No Tag), `tag` (Tag with a
  `severities` map by value), `mono`.
- `component` names a Bloom component (see below) rendered instead of the built-in
  renderer, with props `row` (the whole row) and `col` (this descriptor). A column may
  have both: the server value stays in the row for filtering and sorting, the
  component decides how it looks.

### Actions

`kind` is `navigate` (`url` with `{Field}` placeholders, URL-encoded; `{Field|raw}`
is not) or `server` (`class`/`method` is `ClassMethod(row As %DynamicObject) As %Status`).
`confirm: true` asks first; `when` hides the button on non-matching rows. Server
actions re-check `resource` on invocation and are written to `^Portal.Audit` with the
contributing class.

### Bulk actions

```objectscript
return:slot="page.user.list.bulk-actions" [{"id": "acme.export", "label": "Export", "icon": "pi pi-download",
    "confirm": true, "class": "Acme.Portal.Ext", "method": "Export", "resource": "%Admin_Secure"}]
...
ClassMethod Export(rows As %DynamicArray) As %Status { ... }
```

Contributing a bulk action turns on checkbox selection for that list. The button sits
in the page header with the selection count as a badge, is disabled while nothing is
selected, and calls `method(rows)` with the selected rows through
`InvokeBulkAction`, which re-checks `resource` and writes an audit row holding the
selected row keys. `when` sees `rows` (the selection), e.g. `rows.length <= 50`.

### Fields

```objectscript
return:slot="page.user.edit.fields" [{"key": "CostCentre", "label": "Cost centre", "section": "Acme", "order": 500,
    "class": "Acme.Portal.Ext", "loader": "LoadCostCentre", "method": "SaveCostCentre"}]
...
ClassMethod LoadCostCentre(name As %String) As %String { return $get(^AcmeCC(name)) }
ClassMethod SaveCostCentre(name As %String, value As %String) As %Status { set ^AcmeCC(name) = value  return $$$OK }
```

The portal never stores an extension field: `loader(name)` seeds the value when the
page opens an existing object, `method(name, value)` is called after the page's own
save succeeded. The value is stripped from the object before the page's `Save`, so the
underlying `%Api.Admin` endpoint never sees it. Types and the other keys are the same as
for core fields — see `Portal.EditPage`.

### Widgets

```objectscript
return:slot="page.home.widgets.dashboard" [{"id": "acme.queue", "component": "Acme.Portal.QueueWidget",
    "title": "Queue depth", "width": 2, "order": 50}]
```

| Slot | Page | `ctx` prop |
|---|---|---|
| `page.home.widgets.dashboard` | `Portal.Home`, grid below the navigation tiles | `null` |
| `page.<pageId>.widgets.footer` | every `Portal.ListPage`, grid below the table | the rows array |
| `page.<pageId>.widgets.sidebar` | every `Portal.EditPage`, column right of the form | the object being edited (live) |
| `page.<pageId>.widgets.<name>` | wherever a page put `<ext-slot name="<name>">` | whatever that slot's `ctx` says |

Each widget is a Card (titled when `title` is set) spanning `width` grid columns
(1–3; stacked slots such as the sidebar ignore it). With nothing contributed the page
layout is unchanged.

#### Declaring a slot on a page

Any `Portal.Page` template can open a widget slot with one tag on one line:

```html
<ext-slot name="after-form" ctx="obj" layout="grid" class="mt-4" />
```

`name` completes the slot id (`page.<PAGEID>.widgets.after-form`); `ctx` is the
expression passed to every widget's `ctx` prop (default `null`); `layout` is `grid`
(three columns, `width` honoured) or `stack`; `class` is added to the container. The
tag is expanded when the page is emitted and the slot appears automatically in the
Extensions screen, because `Portal.Page.WidgetSlots()` scans the class's XData for
`<ext-slot`.

## Pages

An extension can ship whole pages, not only items on existing ones. A page is a
`Portal.Page` (or `Portal.ListPage` / `Portal.EditPage`) subclass in the extension's
own package; `Portal.Page` names the shell in its `LAYOUT` parameter, so the page is
wrapped by `Portal.Layout` wherever it lives and is served at
`/csp/portal/<Class>.cls`. Three things tie it in:

- `PAGEID` — its identity for extension points: a list page gets
  `page.<PAGEID>.columns/actions/bulk-actions`, an edit page `page.<PAGEID>.fields`,
  and every `<ext-slot>` it declares becomes `page.<PAGEID>.widgets.<name>`; the slots
  appear on the Extensions screen automatically because `Portal.Ext.Slots` scans every
  concrete `Portal.Page` subclass;
- `RESOURCE` — the IRIS resource checked before the page renders (empty: any
  authenticated user);
- a `shell.nav` item from the contribution, with the same `resource` so users who
  cannot open the page do not see the entry, and a `group` of its own if none fits.

```objectscript
Class Acme.Portal.Queue Extends Portal.ListPage
{
Parameter RESOURCE = "%Acme_Queue";
Parameter PAGEID = "acme.queue";
Parameter TITLE = "Queue";
ClassMethod CoreColumns() As %DynamicArray { return [{"key": "Id", "label": "Id", "order": 10}] }
ClassMethod Rows() As %DynamicArray { return ##class(Acme.Portal.QueueService).List() }
}
```

```objectscript
return:slot="shell.nav" [{"id": "acme.queue", "label": "Queue", "icon": "pi pi-inbox", "group": "Acme",
    "url": "Acme.Portal.Queue.cls", "order": 300, "resource": "%Acme_Queue"}]
```

`PortalExt.Example.HelloPage` in the example module is the minimal version: a
`Portal.Page` with a template, a widget slot of its own and a nav entry under
"Examples".

## Components

A component is a class extending `Banksia.Bloom.Component`: an XData `Template`
(Vue markup using the PrimeVue set registered in `src/vue/primeVue.ts`, `Button` as
`PButton`), properties that become reactive `data`, `ClientMethod`s that become
`methods`, and `WebMethod`s the client can call. `PROPS` lists the Vue props.

```objectscript
Class Acme.Portal.QueueWidget Extends Banksia.Bloom.Component
{
Parameter PROPS = "ctx";
Property depth As %Integer [ InitialExpression = 0 ];
Method %OnNew() As %Status { set ..depth = ..Depth()  return $$$OK }
ClassMethod Depth() As %Integer { return $get(^AcmeQueue("depth"), 0) }
ClassMethod Read() As %String [ WebMethod ] { return {"depth": (..Depth())}.%ToJSON() }
ClientMethod refresh() [ Language = javascript ] { this.depth = JSON.parse(await this.Read()).depth; }
XData Template [ MimeType = text/vue ]
{
<div class="flex items-center justify-between">
  <span class="text-3xl font-semibold">{{ depth }}</span>
  <PButton icon="pi pi-refresh" text rounded @click="refresh" />
</div>
}
}
```

How it works:

- The page emitter (`Banksia.Bloom.Page.OnPage`) instantiates every component the
  page references (`%OnNew` runs server-side, so initial state is computed there),
  writes it once as a Vue component definition, and registers it with the app. The
  Vue name is the class name without `.`, `-` and `%` (`AcmePortalQueueWidget`).
- WebMethods are proxied through `%CSP.Broker` like page WebMethods; they run as the
  logged-in user in the portal's namespace.
- A component that does not exist or does not extend `Banksia.Bloom.Component` is
  skipped and reported against the extension on the Extensions screen.
- Property types emitted to `data`: `%String`, `%Integer`, `%Boolean`,
  `%DynamicArray`, `%DynamicObject`. Anything else is not emitted.
- Tailwind scans `src/cls`, so a utility class not used anywhere yet needs a frontend
  rebuild (`npm run build-only`); PrimeVue components need no build.

## Checklist

1. Class extends `Portal.Ext.Contribution`, `ORDER` ≥ 100, ids prefixed with your
   extension name (`acme.queue`) so they cannot collide; manifest parameters filled in.
2. Put `resource` on anything that should not be visible to every portal user.
3. Compile, open `Portal.Extensions.cls`: the extension is listed, enabled and has no
   errors or warnings; check the slots you target in the "Extension points" reference.
4. Open the pages you contributed to; check `^Portal.Ext("error")` again after using
   a column, field or widget.
