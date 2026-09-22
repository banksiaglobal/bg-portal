/// Create or edit a web application. The form covers the common subset of
/// Security.Applications properties; everything else stays in the classic portal
/// until the corresponding screen is migrated.
Class Portal.WebApp.Edit Extends Portal.EditPage
{

Parameter RESOURCE = "%Admin_Secure";

Parameter PAGEID = "webapp.edit";

Parameter TITLE = "Web Application";

Parameter NOUN = "web application";

Parameter LISTURL = "Portal.WebApp.List.cls";

Property namespaces As %DynamicArray;

Method Fields() As %DynamicArray
{
    return [
        {"key": "Name", "label": "Name", "placeholder": "/csp/myapp", "colSpan": 2, "order": 10},
        {"key": "NameSpace", "label": "Namespace", "type": "select", "options": "namespaces", "placeholder": "Select namespace", "order": 20},
        {"key": "Resource", "label": "Resource", "order": 30},
        {"key": "Description", "label": "Description", "colSpan": 2, "order": 40},
        {"key": "DispatchClass", "label": "Dispatch class", "placeholder": "REST.Dispatch", "order": 50},
        {"key": "Path", "label": "Physical path", "order": 60},
        {"key": "CookiePath", "label": "Cookie path", "order": 70},
        {"key": "Timeout", "label": "Session timeout (s)", "type": "number", "order": 80},
        {"key": "Enabled", "label": "Enabled", "type": "toggle", "order": 200},
        {"key": "CSRFToken", "label": "CSRF token", "type": "toggle", "order": 210},
        {"key": "CSPZENEnabled", "label": "CSP/Zen", "type": "toggle", "order": 220},
        {"key": "IsNameSpaceDefault", "label": "Namespace default", "type": "toggle", "order": 230}
    ]
}

ClassMethod Load(name As %String) As %DynamicObject
{
    return ##class(Portal.WebApp.Service).Get(name)
}

ClassMethod Defaults() As %DynamicObject
{
    return {"Name": "", "NameSpace": "", "Description": "", "Enabled": true, "DispatchClass": "", "Path": "",
            "Resource": "", "Timeout": 900, "CSRFToken": false, "CookiePath": "", "CSPZENEnabled": true, "IsNameSpaceDefault": false}
}

ClassMethod Save(obj As %DynamicObject) As %Status
{
    return ##class(Portal.WebApp.Service).Save(obj)
}

Method OnLoad() As %Status
{
    set ..namespaces = ..ListNamespaces()
    return $$$OK
}

Method Subtitle() As %String
{
    return ..obj.TypeDisplay _ " application"
}

ClassMethod ListNamespaces() As %DynamicArray
{
    set out = []
    do ##class(%SYS.Namespace).ListAll(.list)
    set ns = ""
    for {
        set ns = $order(list(ns))
        quit:ns=""
        continue:$extract(ns)="^"
        do out.%Push(ns)
    }
    return out
}

}
