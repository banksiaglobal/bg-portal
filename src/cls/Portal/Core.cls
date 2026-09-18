/// Built-in shell content. The portal's own navigation is just the first contribution,
/// so site extensions and core items go through exactly the same path.
Class Portal.Core Extends Portal.Ext.Contribution
{

Parameter ORDER As INTEGER = 0;

ClassMethod NavItems() As %DynamicArray
{
    return [
        {"id": "home", "label": "Home", "icon": "pi pi-home", "url": "Portal.Home.cls", "order": 0},
        {"id": "security.webapps", "label": "Web Applications", "icon": "pi pi-globe", "group": "Security",
         "url": "Portal.WebApp.List.cls", "order": 100, "resource": "%Admin_Secure"},
        {"id": "system.extensions", "label": "Extensions", "icon": "pi pi-th-large", "group": "System",
         "url": "Portal.Extensions.cls", "order": 900, "resource": "%Admin_Manage"}
    ]
}

ClassMethod UserMenuItems() As %DynamicArray
{
    return [
        {"id": "classic", "label": "Classic portal", "icon": "pi pi-external-link", "url": "/csp/sys/UtilHome.csp", "order": 100},
        {"id": "logout", "label": "Logout", "icon": "pi pi-sign-out", "url": "Portal.Logout.cls", "order": 900}
    ]
}

ClassMethod FooterItems() As %DynamicArray
{
    return [
        {"id": "safemode", "label": "Safe mode", "url": "?safemode=1", "order": 900}
    ]
}

ClassMethod Actions(pageId As %String) As %DynamicArray
{
    return:pageId'="webapp.list" []
    return [
        {"id": "edit", "label": "Edit", "icon": "pi pi-pencil", "kind": "navigate",
         "url": "Portal.WebApp.Edit.cls?name={Name}", "order": 10},
        {"id": "disable", "label": "Disable", "icon": "pi pi-pause", "kind": "server", "severity": "warn", "confirm": true,
         "class": "Portal.WebApp.Service", "method": "Disable", "order": 20, "resource": "%Admin_Secure",
         "visibleIf": {"field": "Enabled", "equals": true}},
        {"id": "enable", "label": "Enable", "icon": "pi pi-play", "kind": "server", "severity": "success",
         "class": "Portal.WebApp.Service", "method": "Enable", "order": 20, "resource": "%Admin_Secure",
         "visibleIf": {"field": "Enabled", "equals": false}},
        {"id": "delete", "label": "Delete", "icon": "pi pi-trash", "kind": "server", "severity": "danger", "confirm": true,
         "class": "Portal.WebApp.Service", "method": "Delete", "order": 90, "resource": "%Admin_Secure"}
    ]
}

}
