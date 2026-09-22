/// Base class for portal extensions.
///
/// Subclass it, override Contribute(slot), compile. Discovery is automatic (see
/// Portal.Ext.Registry). Every hook returns declarative data; the portal
/// only executes extension code through the class/method pairs an extension declares
/// itself in a column, field, action or component.
///
/// Slots (Portal.Ext.Slots lists them all, Portal.Extensions.cls shows them with counts):
///   shell.nav, shell.topbar, shell.user-menu, shell.footer, shell.head
///   page.<pageId>.columns        Portal.ListPage tables
///   page.<pageId>.actions        row buttons on a Portal.ListPage
///   page.<pageId>.bulk-actions   toolbar buttons acting on the selected rows of a Portal.ListPage
///   page.<pageId>.fields         inputs on a Portal.EditPage
///   page.<pageId>.widgets.<name> cards in an <ext-slot name="<name>"> of a page (footer on lists,
///                                sidebar on edit pages, dashboard on home, plus any a page declares)
///
/// Item shapes (all fields optional unless stated):
///   shell.nav          {id*, label*, url*, icon, group, order, resource}
///   shell.topbar       {id*, label*, url*, icon, order, resource}
///   shell.user-menu    {id*, label*, url*, icon, order}
///   shell.footer       {id*, label*, url, order}
///   shell.head         {id*, url, css, src, js, page, order}
///                      url: stylesheet link; css: inline CSS text; src: script link;
///                      js: inline JS text (runs once, at head-parse time, before the app
///                      mounts). At least one of url/css/src/js is required.
///                      page: PAGEID to scope the item to; empty applies it to every page.
///   columns            {key*, label*, order, sortable, type, severities, class, method, component, when, resource}
///                      class/method: ClassMethod(row As %DynamicObject) As %String, computed server-side per row
///                      component: a Banksia.Bloom.Component class (PROPS = "row,col") rendering the cell client-side
///   actions            {id*, label*, kind*, order, icon, severity, resource, confirm, when,
///                       url   (kind "navigate": {Field} placeholders are resolved from the row and URL-encoded; {Field|raw} is not),
///                       class, method (kind "server": ClassMethod(row As %DynamicObject) As %Status)}
///   bulk-actions       {id*, label*, order, icon, severity, resource, confirm, when,
///                       class*, method* (ClassMethod(rows As %DynamicArray) As %Status)}
///   fields             {key*, label*, type, order, section, colSpan, placeholder, help, options, resource,
///                       when, newOnly, existingOnly, class, loader, method}
///                      the value is kept under obj[key] on the client only; the extension persists it itself:
///                      loader(name As %String) As %String seeds it, method(name As %String, value) As %Status
///                      is called after the page's own Save succeeded.
///   widgets            {id*, component*, order, title, width, when, resource}
///                      component: a Banksia.Bloom.Component class (PROPS = "ctx") rendered in a Card (titled when
///                      `title` is set) spanning `width` grid columns (1-3). `ctx` is what the slot passes:
///                      the rows on a list footer, the object on an edit sidebar, null on the dashboard.
///
/// `when` is a display-only expression evaluated on the client (see Portal.Page.evalWhen):
/// dot paths, literals, ! && || == != < <= > >=, parentheses. Context names: `row` (columns,
/// actions), `rows` (the selection, bulk actions; all rows for columns), `obj` and `isNew`
/// (fields), `ctx` (widgets), plus `user` and `page` everywhere.
///
/// Overriding core: any item may carry `"replaces": "<id>"` to take that item's place in the
/// slot (position inherited unless it sets `order`; it may reuse the id), and an item of the
/// form `{"hide": "<id>"}` removes one. Both win regardless of load order and are recorded in
/// ^Portal.Ext("override", slot, id). A replacement is still subject to its own `resource`.
/// Accidental duplicates (same id, or two replacers of one target) remain collisions.
///
/// `resource` on any item is enforced server-side: the item is not emitted unless
/// the current user holds USE on it, and server actions re-check it on invocation.
///
/// Every item is validated against Portal.Ext.Schema (required keys, types, enumerations,
/// `when` syntax): an invalid item is dropped and reported in ^Portal.Ext("error", class, slot),
/// an unknown key is a warning in ^Portal.Ext("warning", class, slot) and the item is kept.
/// The validated output of Contribute(slot) is cached per contribution set (see
/// Portal.Ext.Registry): a hook runs once per compile of the contribution classes, not
/// per request, so it must be a pure function of the slot; ?nocache=1 bypasses the cache.
///
/// Manifest: ID, NAME, VERSION, PUBLISHER, HOMEPAGE, REQUIRES describe the extension to
/// admins (Portal.Extensions.cls); Manifest() assembles them. When the class is part of an
/// installed ZPM module the registry attaches the module's name and version.
///
/// Lifecycle: the registry runs OnInstall() the first time it sees the class,
/// OnUpgrade(fromVersion) when VERSION changed since, OnEnable()/OnDisable() from the
/// admin switch, and OnUninstall() when an admin retires the extension or the ZPM module
/// is uninstalled (see Portal.Ext.Registry.Uninstall / Sync). A failing hook is recorded in
/// ^Portal.Ext("error", class, "<hook>") and shown on the Extensions screen; a failing
/// OnEnable/OnDisable leaves the switch where it was.
Class Portal.Ext.Contribution Extends %RegisteredObject [ Abstract ]
{

/// Stable identifier, reverse-DNS style ("com.acme.portal.queue"). Defaults to the class name.
Parameter ID;

/// Display name. Defaults to the class name.
Parameter NAME;

/// Semantic version of the extension.
Parameter VERSION = "0.0.0";

Parameter PUBLISHER;

Parameter HOMEPAGE;

/// Comma-separated IRIS resources the extension uses. Informational: shown to admins,
/// flagged when the viewing user lacks one. Enforcement is per item through `resource`.
Parameter REQUIRES;

/// Extension API version this contribution was written against. The registry
/// refuses contributions targeting another version rather than half-loading them.
Parameter APIVERSION As INTEGER = 2;

/// Load order. Core contributions use 0-99; site extensions should stay at 100+.
/// Within one slot, items are ordered by their own `order`, then by load order.
Parameter ORDER As INTEGER = 100;

/// The hook: items for one slot (see the slot list above). Return [] for slots you do not fill.
ClassMethod Contribute(slot As %String) As %DynamicArray
{
    return []
}

/// {id, name, version, publisher, homepage, requires: [...], description, class, apiVersion, order}.
/// Override to compute any of it; `description` defaults to the class doc comment.
ClassMethod Manifest() As %DynamicObject
{
    set class = $classname()
    set def = ##class(%Dictionary.CompiledClass).%OpenId(class)
    set requires = []
    for i = 1:1:$length(..#REQUIRES, ",") {
        set r = $zstrip($piece(..#REQUIRES, ",", i), "<>W")
        do:r'="" requires.%Push(r)
    }
    return {
        "id": ($select(..#ID '= "": ..#ID, 1: class)),
        "name": ($select(..#NAME '= "": ..#NAME, 1: class)),
        "version": (..#VERSION),
        "publisher": (..#PUBLISHER),
        "homepage": (..#HOMEPAGE),
        "requires": (requires),
        "description": ($select($isobject(def): def.Description, 1: "")),
        "class": (class),
        "apiVersion": (+..#APIVERSION),
        "order": (+..#ORDER)
    }
}

// ---- Lifecycle. All default to success.

ClassMethod OnInstall() As %Status
{
    return $$$OK
}

ClassMethod OnUpgrade(fromVersion As %String) As %Status
{
    return $$$OK
}

ClassMethod OnEnable() As %Status
{
    return $$$OK
}

ClassMethod OnDisable() As %Status
{
    return $$$OK
}

ClassMethod OnUninstall() As %Status
{
    return $$$OK
}

}
