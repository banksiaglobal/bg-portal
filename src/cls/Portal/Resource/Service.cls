/// Domain adapter over %Api.Admin.Endpoints.Security.Resource. This is the only place the
/// portal touches resource management; pages and extension actions call this, never
/// %Api.Admin.* or Security.* directly. See Portal.Api.Service for the mechanics.
Class Portal.Resource.Service Extends Portal.Api.Service
{

Parameter ENDPOINT = "%Api.Admin.Endpoints.Security.Resource";

Parameter SCHEMAMETHOD = "PutRequestBodySchema";

/// One row per resource with the endpoint's list columns: Name, Description,
/// PublicPermission, ResourceType, AllowDelete.
ClassMethod List() As %DynamicArray
{
    new $namespace
    set $namespace = "%SYS"
    set list = ..Invoke(..#TYPELIST, "", {}, .sc)
    return:$$$ISERR(sc) []
    return list
}

/// The list row for one resource, or "" when it does not exist. The get shape lacks
/// ResourceType and AllowDelete, so the edit page and Delete use this instead.
ClassMethod Find(name As %String) As %DynamicObject
{
    set iter = ..List().%GetIterator()
    while iter.%GetNext(.i, .row) {
        return:row.Name=name row
    }
    return ""
}

/// The endpoint answers a missing resource with an OK status and an empty object
/// rather than an error, so the base Get() would return {} for it.
ClassMethod Get(name As %String) As %DynamicObject
{
    new $namespace
    set $namespace = "%SYS"
    set row = ..Invoke(..#TYPEGET, name, {}, .sc)
    return:$$$ISERR(sc)||(row.%Size()=0) ""
    set row.Name = name
    return row
}

/// Creates the resource when it does not exist, otherwise modifies it (PUT does both).
///
/// The endpoint treats an empty PublicPermission as invalid (its 400 is swallowed
/// in-process, leaving nothing changed), yet "no public permission" is the normal
/// case and no endpoint request can express it. Those two paths — create with no
/// public permission, clear an existing one — are the one place the portal goes to
/// Security.Resources directly; everything else is the endpoint.
ClassMethod Save(resource As %DynamicObject) As %Status
{
    new $namespace
    set $namespace = "%SYS"
    set name = resource.Name
    return:name="" $$$ERROR($$$GeneralError, "Resource name is required")
    set body = ..SchemaSubset(resource)
    // the endpoint answers an invalid permission with a 400 that is invisible in-process
    if body.%IsDefined("PublicPermission") && ($translate(body.PublicPermission, "RWU") '= "") {
        return $$$ERROR($$$GeneralError, "Public permission must be a combination of R, W and U")
    }
    set clear = body.%IsDefined("PublicPermission") && (body.PublicPermission = "")
    if 'clear {
        do ..Invoke(..#TYPEPUT, name, body, .sc)
        return sc
    }
    return:'$isobject(..Get(name)) ##class(Security.Resources).Create(name, body.Description, "")
    do body.%Remove("PublicPermission")
    if body.%Size() {
        do ..Invoke(..#TYPEPUT, name, body, .sc)
        return:$$$ISERR(sc) sc
    }
    set props("PublicPermission") = ""
    return ##class(Security.Resources).Modify(name, .props)
}

/// The endpoint deletes system resources without complaint, so the list's AllowDelete
/// flag is enforced here.
ClassMethod Delete(row As %DynamicObject) As %Status
{
    new $namespace
    set $namespace = "%SYS"
    set current = ..Find(row.Name)
    return:'$isobject(current) $$$ERROR($$$GeneralError, "Resource '" _ row.Name _ "' does not exist")
    return:'current.AllowDelete $$$ERROR($$$GeneralError, "Resource '" _ row.Name _ "' is system-defined and cannot be deleted")
    do ..Invoke(..#TYPEDELETE, row.Name, {}, .sc)
    return sc
}

/// Names of all resources on the instance, for the resource picker on the role page.
ClassMethod Names() As %DynamicArray
{
    set out = []
    set iter = ..List().%GetIterator()
    while iter.%GetNext(.i, .row) {
        do out.%Push(row.Name)
    }
    return out
}

}
