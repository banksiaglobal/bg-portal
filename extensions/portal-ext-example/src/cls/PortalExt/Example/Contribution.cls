/// Reference extension, shipped as its own ZPM module (portal-ext-example). Shows every
/// slot a site contribution can use, a page of its own (PortalExt.Example.HelloPage, with
/// its sidebar entry), an override (`replaces`), a `hide`, and every lifecycle hook; each hook leaves a
/// timestamp in ^PortalExt.Example("lifecycle", hook) so its effect is observable.
/// Uninstall it (zpm "uninstall portal-ext-example") once real extensions exist.
Class PortalExt.Example.Contribution Extends Portal.Ext.Contribution
{

Parameter ID = "com.banksiaglobal.portal.example";

Parameter NAME = "Example extension";

Parameter VERSION = "0.1.0";

Parameter PUBLISHER = "Banksia Global";

Parameter HOMEPAGE = "https://github.com/banksia-global/iris-portal";

Parameter REQUIRES = "%Admin_Secure";

Parameter ORDER As INTEGER = 500;

ClassMethod Contribute(slot As %String) As %DynamicArray
{
    // A page shipped by the extension, under its own sidebar group.
    return:slot="shell.nav" [
        {"id": "example.hello", "label": "Extra Page", "icon": "pi pi-star", "group": "Examples",
         "url": "PortalExt.Example.HelloPage.cls", "order": 300}
    ]
    // Hides a core item: the "Classic portal" link in the user menu.
    return:slot="shell.user-menu" [
        {"hide": "classic"}
    ]
    return:slot="shell.footer" [
        {"id": "example.docs", "label": "Extension example", "url": "Portal.Extensions.cls", "order": 100}
    ]
    // A server-computed column with a custom cell renderer.
    return:slot="page.webapp.list.columns" [
        {"key": "CSRF", "label": "CSRF", "order": 45, "class": "PortalExt.Example.Contribution", "method": "CsrfColumn",
         "component": "PortalExt.Example.CsrfCell"}
    ]
    // Replaces a core item: same id "delete" so the audit trail reads the same, but the
    // action refuses system applications and `source` shows this extension.
    return:slot="page.webapp.list.actions" [
        {"id": "example.open", "label": "Open in browser", "icon": "pi pi-external-link", "kind": "navigate",
         "url": "{Name|raw}/", "order": 5, "when": "row.Enabled"},
        {"id": "delete", "replaces": "delete", "label": "Delete", "icon": "pi pi-trash", "kind": "server", "severity": "danger", "confirm": true,
         "class": "PortalExt.Example.Contribution", "method": "DeleteApp", "resource": "%Admin_Secure"}
    ]
    // A bulk action on the selection; shown only while every selected app is enabled.
    return:slot="page.webapp.list.bulk-actions" [
        {"id": "example.touch", "label": "Touch", "icon": "pi pi-check-square", "order": 10, "confirm": true,
         "class": "PortalExt.Example.Contribution", "method": "Touch", "resource": "%Admin_Secure"}
    ]
    // A note per user, stored by the extension itself: the portal only carries the value
    // between the form and the loader/method pair.
    return:slot="page.user.edit.fields" [
        {"key": "ExampleNote", "label": "Note (extension example)", "type": "textarea", "section": "Extension example", "colSpan": 2, "order": 500,
         "class": "PortalExt.Example.Contribution", "loader": "LoadNote", "method": "SaveNote"}
    ]
    // A live counter on the home page and a read-only summary beside an existing user.
    return:slot="page.home.widgets.dashboard" [
        {"id": "example.userstats", "component": "PortalExt.Example.UserStats", "title": "Users", "order": 100, "resource": "%Admin_Secure"}
    ]
    return:slot="page.user.edit.widgets.sidebar" [
        {"id": "example.usersummary", "component": "PortalExt.Example.UserSidebar", "title": "Summary", "order": 100, "when": "ctx.Name != ''"}
    ]
    return []
}

/// Guarded delete: system applications stay; everything else goes through the core service.
ClassMethod DeleteApp(row As %DynamicObject) As %Status
{
    return:($extract(row.Name, 1, 8) = "/csp/sys") $$$ERROR($$$GeneralError, "Refusing to delete system application " _ row.Name)
    return ##class(Portal.WebApp.Service).Delete(row)
}

ClassMethod CsrfColumn(row As %DynamicObject) As %String
{
    return $select(row.CSRFToken: "on", 1: "off")
}

/// Records the selection; a real bulk action would act on each row.
ClassMethod Touch(rows As %DynamicArray) As %Status
{
    set iter = rows.%GetIterator()
    while iter.%GetNext(.i, .row) {
        set ^PortalExt.Example("touched", row.Name) = $horolog
    }
    return $$$OK
}

ClassMethod LoadNote(name As %String) As %String
{
    return $get(^PortalExt.Example("note", name))
}

ClassMethod SaveNote(name As %String, value As %String) As %Status
{
    if value = "" {
        kill ^PortalExt.Example("note", name)
    } else {
        set ^PortalExt.Example("note", name) = value
    }
    return $$$OK
}

// ---- Lifecycle: every hook records when it ran.

ClassMethod Mark(hook As %String) As %Status
{
    set ^PortalExt.Example("lifecycle", hook) = $zdatetime($horolog, 3)
    return $$$OK
}

ClassMethod OnInstall() As %Status
{
    return ..Mark("OnInstall")
}

ClassMethod OnUpgrade(fromVersion As %String) As %Status
{
    set ^PortalExt.Example("lifecycle", "OnUpgrade", "from") = fromVersion
    return ..Mark("OnUpgrade")
}

ClassMethod OnEnable() As %Status
{
    return ..Mark("OnEnable")
}

ClassMethod OnDisable() As %Status
{
    return ..Mark("OnDisable")
}

/// Drops everything the extension stored; the marker for this hook is the one thing left.
ClassMethod OnUninstall() As %Status
{
    kill ^PortalExt.Example
    return ..Mark("OnUninstall")
}

}
