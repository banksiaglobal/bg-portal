/// Create or edit a security resource: description and public permission. System
/// resources can be edited but not deleted.
Class Portal.Resource.Edit Extends Portal.EditPage
{

Parameter RESOURCE = "%Admin_Secure";

Parameter PAGEID = "resource.edit";

Parameter TITLE = "Resource";

Parameter NOUN = "resource";

Parameter LISTURL = "Portal.Resource.List.cls";

Parameter COLUMNS As INTEGER = 1;

Method Fields() As %DynamicArray
{
    return [
        {"key": "Name", "label": "Name", "order": 10},
        {"key": "Description", "label": "Description", "order": 20},
        {"key": "PublicPermission", "label": "Public permission", "type": "perms", "order": 30,
         "help": "Permissions every user holds on this resource without being granted a role. Leave empty for none."}
    ]
}

/// The endpoint's GET shape lacks type and deletability; both come from the list row.
ClassMethod Load(name As %String) As %DynamicObject
{
    set resource = ##class(Portal.Resource.Service).Get(name)
    return:'$isobject(resource) ""
    set row = ##class(Portal.Resource.Service).Find(name)
    set resource.ResourceType = $select($isobject(row): row.ResourceType, 1: "")
    do resource.%Set("AllowDelete", $select($isobject(row): row.AllowDelete, 1: 1), "boolean")
    return resource
}

ClassMethod Defaults() As %DynamicObject
{
    return {"Name": "", "Description": "", "PublicPermission": "", "ResourceType": "", "AllowDelete": true}
}

ClassMethod Save(obj As %DynamicObject) As %Status
{
    return ##class(Portal.Resource.Service).Save(obj)
}

Method Subtitle() As %String
{
    return ..obj.ResourceType _ " resource" _ $select(..obj.AllowDelete: "", 1: " (system-defined)")
}

}
