/// Roles list. Columns and row actions are the union of the core set declared here
/// and whatever Portal.Ext.Registry contributes for page id "role.list".
Class Portal.Role.List Extends Portal.ListPage
{

Parameter RESOURCE = "%Admin_Secure";

Parameter PAGEID = "role.list";

Parameter TITLE = "Roles";

Parameter SUBTITLE = "Roles defined on this instance";

Parameter CREATEURL = "Portal.Role.Edit.cls";

Parameter NEWLABEL = "New role";

Parameter ROWURL = "Portal.Role.Edit.cls?name={Name}";

Parameter CONFIRMNOUN = " role";

ClassMethod CoreColumns() As %DynamicArray
{
    return [
        {"key": "Name", "label": "Name", "sortable": true, "order": 10},
        {"key": "Description", "label": "Description", "sortable": true, "order": 20},
        {"key": "CreatedBy", "label": "Created by", "sortable": true, "order": 30},
        {"key": "EscalationOnly", "label": "Escalation only", "type": "boolean", "sortable": true, "order": 40}
    ]
}

ClassMethod Rows() As %DynamicArray
{
    return ##class(Portal.Role.Service).List()
}

}
