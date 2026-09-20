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
        {"id": "security.users", "label": "Users", "icon": "pi pi-users", "group": "Security",
         "url": "Portal.User.List.cls", "order": 110, "resource": "%Admin_Secure"},
        {"id": "security.roles", "label": "Roles", "icon": "pi pi-id-card", "group": "Security",
         "url": "Portal.Role.List.cls", "order": 120, "resource": "%Admin_Secure"},
        {"id": "security.resources", "label": "Resources", "icon": "pi pi-shield", "group": "Security",
         "url": "Portal.Resource.List.cls", "order": 130, "resource": "%Admin_Secure"},
        {"id": "operations.processes", "label": "Processes", "icon": "pi pi-microchip", "group": "Operations",
         "url": "Portal.Process.List.cls", "order": 200, "resource": "%Admin_Operate"},
        {"id": "operations.websessions", "label": "Web Sessions", "icon": "pi pi-desktop", "group": "Operations",
         "url": "Portal.WebSession.List.cls", "order": 210, "resource": "%Admin_Operate"},
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
    return:pageId="user.list" ..UserActions()
    return:pageId="process.list" ..ProcessActions()
    return:pageId="websession.list" ..WebSessionActions()
    return:pageId="role.list" ..RoleActions()
    return:pageId="resource.list" ..ResourceActions()
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

ClassMethod UserActions() As %DynamicArray
{
    return [
        {"id": "edit", "label": "Edit", "icon": "pi pi-pencil", "kind": "navigate",
         "url": "Portal.User.Edit.cls?name={Name}", "order": 10},
        {"id": "disable", "label": "Disable", "icon": "pi pi-pause", "kind": "server", "severity": "warn", "confirm": true,
         "class": "Portal.User.Service", "method": "Disable", "order": 20, "resource": "%Admin_Secure",
         "visibleIf": {"field": "Enabled", "equals": true}},
        {"id": "enable", "label": "Enable", "icon": "pi pi-play", "kind": "server", "severity": "success",
         "class": "Portal.User.Service", "method": "Enable", "order": 20, "resource": "%Admin_Secure",
         "visibleIf": {"field": "Enabled", "equals": false}},
        {"id": "delete", "label": "Delete", "icon": "pi pi-trash", "kind": "server", "severity": "danger", "confirm": true,
         "class": "Portal.User.Service", "method": "Delete", "order": 90, "resource": "%Admin_Secure"}
    ]
}

ClassMethod ProcessActions() As %DynamicArray
{
    return [
        {"id": "view", "label": "Details", "icon": "pi pi-search", "kind": "navigate",
         "url": "Portal.Process.Detail.cls?id={Pid}", "order": 10},
        {"id": "suspend", "label": "Suspend", "icon": "pi pi-pause", "kind": "server", "severity": "warn",
         "class": "Portal.Process.Service", "method": "Suspend", "order": 20, "resource": "%Admin_Operate",
         "visibleIf": {"field": "CanBeSuspended", "equals": true}},
        {"id": "resume", "label": "Resume", "icon": "pi pi-play", "kind": "server", "severity": "success",
         "class": "Portal.Process.Service", "method": "Resume", "order": 20, "resource": "%Admin_Operate",
         "visibleIf": {"field": "State", "equals": "SUSP"}},
        {"id": "terminate", "label": "Terminate", "icon": "pi pi-times", "kind": "server", "severity": "danger", "confirm": true,
         "class": "Portal.Process.Service", "method": "Terminate", "order": 90, "resource": "%Admin_Operate",
         "visibleIf": {"field": "CanBeTerminated", "equals": true}}
    ]
}

ClassMethod RoleActions() As %DynamicArray
{
    return [
        {"id": "edit", "label": "Edit", "icon": "pi pi-pencil", "kind": "navigate",
         "url": "Portal.Role.Edit.cls?name={Name}", "order": 10},
        {"id": "delete", "label": "Delete", "icon": "pi pi-trash", "kind": "server", "severity": "danger", "confirm": true,
         "class": "Portal.Role.Service", "method": "Delete", "order": 90, "resource": "%Admin_Secure"}
    ]
}

ClassMethod ResourceActions() As %DynamicArray
{
    return [
        {"id": "edit", "label": "Edit", "icon": "pi pi-pencil", "kind": "navigate",
         "url": "Portal.Resource.Edit.cls?name={Name}", "order": 10},
        {"id": "delete", "label": "Delete", "icon": "pi pi-trash", "kind": "server", "severity": "danger", "confirm": true,
         "class": "Portal.Resource.Service", "method": "Delete", "order": 90, "resource": "%Admin_Secure",
         "visibleIf": {"field": "AllowDelete", "equals": true}}
    ]
}

ClassMethod WebSessionActions() As %DynamicArray
{
    return [
        {"id": "end", "label": "End session", "icon": "pi pi-sign-out", "kind": "server", "severity": "danger", "confirm": true,
         "class": "Portal.WebSession.Service", "method": "EndSession", "order": 90, "resource": "%Admin_Operate",
         "visibleIf": {"field": "AllowEndSession", "equals": true}}
    ]
}

}
