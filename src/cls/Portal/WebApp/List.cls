/// Web application list. Columns and row actions are the union of the core set
/// declared here and whatever Portal.Ext.Registry contributes for page id "webapp.list".
Class Portal.WebApp.List Extends Portal.ListPage
{

Parameter RESOURCE = "%Admin_Secure";

Parameter PAGEID = "webapp.list";

Parameter TITLE = "Web Applications";

Parameter SUBTITLE = "CSP, REST and client applications defined on this instance";

Parameter CREATEURL = "Portal.WebApp.Edit.cls";

Parameter NEWLABEL = "New application";

Parameter ROWURL = "Portal.WebApp.Edit.cls?name={Name}";

Parameter CONFIRMNOUN = " web application";

ClassMethod CoreColumns() As %DynamicArray
{
    return [
        {"key": "Name", "label": "Name", "sortable": true, "order": 10},
        {"key": "TypeDisplay", "label": "Type", "sortable": true, "order": 20},
        {"key": "NameSpace", "label": "Namespace", "sortable": true, "order": 30},
        {"key": "Enabled", "label": "Enabled", "type": "boolean", "sortable": true, "order": 40},
        {"key": "DispatchClass", "label": "Dispatch class", "sortable": true, "order": 50},
        {"key": "Path", "label": "Path", "order": 60},
        {"key": "Resource", "label": "Resource", "sortable": true, "order": 70},
        {"key": "Description", "label": "Description", "order": 80}
    ]
}

ClassMethod Rows() As %DynamicArray
{
    return ##class(Portal.WebApp.Service).List()
}

}
