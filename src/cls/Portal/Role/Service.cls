/// Domain adapter over %Api.Admin.Endpoints.Security.Role. This is the only place the
/// portal touches role management; pages and extension actions call this, never
/// %Api.Admin.* or Security.* directly. See Portal.Api.Service for the mechanics.
Class Portal.Role.Service Extends Portal.Api.Service
{

Parameter ENDPOINT = "%Api.Admin.Endpoints.Security.Role";

Parameter SCHEMAMETHOD = "PutRequestBodySchema";

/// Request type understood only by the role endpoint: users and roles holding the role.
Parameter TYPEOWNERLIST = 10;

/// One row per role with the endpoint's list columns: Name, Description, CreatedBy,
/// EscalationOnly.
ClassMethod List() As %DynamicArray
{
    new $namespace
    set $namespace = "%SYS"
    set list = ..Invoke(..#TYPELIST, "", {}, .sc)
    return:$$$ISERR(sc) []
    return list
}

/// Creates the role when it does not exist, otherwise modifies it (PUT does both).
/// Resources are `[{Name, Permissions}]` with Permissions as a string of R/W/U.
ClassMethod Save(role As %DynamicObject) As %Status
{
    new $namespace
    set $namespace = "%SYS"
    set name = role.Name
    return:name="" $$$ERROR($$$GeneralError, "Role name is required")
    set body = ..SchemaSubset(role)
    do:body.%IsDefined("EscalationOnly") body.%Set("EscalationOnly", +body.EscalationOnly, "boolean")
    do ..Invoke(..#TYPEPUT, name, body, .sc)
    return sc
}

/// Users and roles that hold the role: `[{Name, Type, AdminOption}]` where Type is
/// "User", "Role" or "User (escalation)".
ClassMethod Members(name As %String) As %DynamicArray
{
    new $namespace
    set $namespace = "%SYS"
    set list = ..Invoke(..#TYPEOWNERLIST, name, {}, .sc)
    return:$$$ISERR(sc) []
    return list
}

/// Names of all roles on the instance, for the granted-roles picker.
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
