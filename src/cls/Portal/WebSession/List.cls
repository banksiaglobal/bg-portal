/// Web session list. Columns and row actions are the union of the core set declared here
/// and whatever Portal.Ext.Registry contributes for page id "websession.list".
/// Sessions have no detail page; the only operations are ending one or a selection.
/// The caller's own session is flagged, cannot be ticked and is refused server-side.
Class Portal.WebSession.List Extends Portal.ListPage
{

Parameter RESOURCE = "%Admin_Operate";

Parameter PAGEID = "websession.list";

Parameter TITLE = "Web Sessions";

Parameter SUBTITLE = "Active web (CSP) sessions on this instance";

Parameter ROWKEY = "ID";

Parameter SHOWREFRESH As BOOLEAN = 1;

ClassMethod CoreColumns() As %DynamicArray
{
    return [
        {"key": "ID", "label": "Session ID", "type": "mono", "sortable": true, "order": 10},
        {"key": "Username", "label": "User", "sortable": true, "order": 20},
        {"key": "Application", "label": "Application", "sortable": true, "order": 30},
        {"key": "Timeout", "label": "Expires", "sortable": true, "order": 40},
        {"key": "Preserve", "label": "Preserve", "sortable": true, "order": 50},
        {"key": "LicenseId", "label": "License ID", "sortable": true, "order": 60},
        {"key": "SesProcessId", "label": "Process", "sortable": true, "order": 70}
    ]
}

ClassMethod Rows() As %DynamicArray
{
    return ##class(Portal.WebSession.Service).List()
}

ClientMethod rowSelectable(row) [ Language = javascript ]
{
    return !!row.AllowEndSession && !row.IsCurrent;
}

ClientMethod describeRow(row) [ Language = javascript ]
{
    return row ? row.ID + ' (' + row.Username + ', ' + row.Application + ')' : '';
}

}
