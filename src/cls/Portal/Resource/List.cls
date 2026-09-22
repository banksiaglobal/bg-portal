/// Resource list. Columns and row actions are the union of the core set declared here
/// and whatever Portal.Ext.Registry contributes for page id "resource.list".
Class Portal.Resource.List Extends Portal.ListPage
{

Parameter RESOURCE = "%Admin_Secure";

Parameter PAGEID = "resource.list";

Parameter TITLE = "Resources";

Parameter SUBTITLE = "Security resources defined on this instance";

Parameter CREATEURL = "Portal.Resource.Edit.cls";

Parameter NEWLABEL = "New resource";

Parameter ROWURL = "Portal.Resource.Edit.cls?name={Name}";

Parameter CONFIRMNOUN = " resource";

ClassMethod CoreColumns() As %DynamicArray
{
    return [
        {"key": "Name", "label": "Name", "sortable": true, "order": 10},
        {"key": "Description", "label": "Description", "sortable": true, "order": 20},
        {"key": "ResourceType", "label": "Type", "sortable": true, "order": 30},
        {"key": "PublicPermission", "label": "Public permission", "sortable": true, "order": 40},
        {"key": "AllowDelete", "label": "User-defined", "type": "boolean", "sortable": true, "order": 50}
    ]
}

ClassMethod Rows() As %DynamicArray
{
    return ##class(Portal.Resource.Service).List()
}

}
