/// User list. Columns and row actions are the union of the core set declared here
/// and whatever Portal.Ext.Registry contributes for page id "user.list".
Class Portal.User.List Extends Portal.ListPage
{

Parameter RESOURCE = "%Admin_Secure";

Parameter PAGEID = "user.list";

Parameter TITLE = "Users";

Parameter SUBTITLE = "User accounts defined on this instance";

Parameter CREATEURL = "Portal.User.Edit.cls";

Parameter NEWLABEL = "New user";

Parameter ROWURL = "Portal.User.Edit.cls?name={Name}";

Parameter CONFIRMNOUN = " user";

ClassMethod CoreColumns() As %DynamicArray
{
    return [
        {"key": "Name", "label": "Name", "sortable": true, "order": 10},
        {"key": "FullName", "label": "Full name", "sortable": true, "order": 20},
        {"key": "Type", "label": "Type", "sortable": true, "order": 30},
        {"key": "Enabled", "label": "Enabled", "type": "boolean", "sortable": true, "order": 40},
        {"key": "Namespace", "label": "Startup namespace", "sortable": true, "order": 50},
        {"key": "Routine", "label": "Startup routine", "order": 60}
    ]
}

ClassMethod Rows() As %DynamicArray
{
    return ##class(Portal.User.Service).List()
}

}
