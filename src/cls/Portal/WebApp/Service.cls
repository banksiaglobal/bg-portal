/// Domain adapter over %Api.Admin.Endpoints.WebApp.App. This is the only place the
/// portal touches web application management; pages and extension actions call this,
/// never %Api.Admin.* or Security.* directly. See Portal.Api.Service for the mechanics.
Class Portal.WebApp.Service Extends Portal.Api.Service
{

Parameter ENDPOINT = "%Api.Admin.Endpoints.WebApp.App";

/// One row per application. Rows carry the endpoint's list columns (Name, TypeDisplay,
/// Enabled, ...) merged with the full detail from Get(), so columns such as Path and
/// Description are available to the list page and to extension columns.
ClassMethod List() As %DynamicArray
{
    new $namespace
    set $namespace = "%SYS"
    set out = []
    set list = ..Invoke(..#TYPELIST, "", {}, .sc)
    return:$$$ISERR(sc) out
    set iter = list.%GetIterator()
    while iter.%GetNext(.i, .item) {
        set row = ..Get(item.Name)
        continue:'$isobject(row)
        set row.TypeDisplay = item.Type
        do out.%Push(row)
    }
    return out
}

/// Creates the application when it does not exist, otherwise modifies it (the endpoint's
/// PUT does both). Only keys in the request schema are applied; anything else
/// (Name, TypeDisplay, ...) is ignored rather than rejected.
ClassMethod Save(app As %DynamicObject) As %Status
{
    new $namespace
    set $namespace = "%SYS"
    set name = app.Name
    return:name="" $$$ERROR($$$GeneralError, "Application name is required")
    do ..Invoke(..#TYPEPUT, name, ..SchemaSubset(app), .sc)
    return sc
}

}
