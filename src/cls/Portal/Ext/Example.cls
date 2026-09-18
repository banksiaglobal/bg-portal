/// Reference extension. Shows every hook a site contribution can use; delete or
/// disable it (Portal.Extensions.cls) once real extensions exist.
Class Portal.Ext.Example Extends Portal.Ext.Contribution
{

Parameter ORDER As INTEGER = 500;

ClassMethod FooterItems() As %DynamicArray
{
    return [{"id": "example.docs", "label": "Extension example", "url": "Portal.Extensions.cls", "order": 100}]
}

ClassMethod Columns(pageId As %String) As %DynamicArray
{
    return:pageId'="webapp.list" []
    return [
        {"key": "CSRF", "label": "CSRF", "order": 45, "class": "Portal.Ext.Example", "method": "CsrfColumn"}
    ]
}

ClassMethod CsrfColumn(row As %DynamicObject) As %String
{
    return $select(row.CSRFToken: "on", 1: "off")
}

ClassMethod Actions(pageId As %String) As %DynamicArray
{
    return:pageId'="webapp.list" []
    return [
        {"id": "example.open", "label": "Open in browser", "icon": "pi pi-external-link", "kind": "navigate",
         "url": "{Name|raw}/", "order": 5}
    ]
}

}
