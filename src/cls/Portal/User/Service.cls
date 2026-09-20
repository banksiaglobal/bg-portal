/// Domain adapter over %Api.Admin.Endpoints.Security.User. This is the only place the
/// portal touches user management; pages and extension actions call this, never
/// %Api.Admin.* or Security.* directly. See Portal.Api.Service for the mechanics.
Class Portal.User.Service Extends Portal.Api.Service
{

Parameter ENDPOINT = "%Api.Admin.Endpoints.Security.User";

Parameter SCHEMAMETHOD = "Schema";

Parameter ROLEENDPOINT = "%Api.Admin.Endpoints.Security.Role";

/// Request type understood only by the user endpoint: change password.
Parameter TYPECHANGEPWD = 10;

/// One row per user with the endpoint's list columns: Name, FullName, Namespace,
/// Routine, Type, Enabled.
ClassMethod List() As %DynamicArray
{
    new $namespace
    set $namespace = "%SYS"
    set list = ..Invoke(..#TYPELIST, "", {}, .sc)
    return:$$$ISERR(sc) []
    return list
}

/// Creates the user (POST, password required) when it does not exist, otherwise
/// modifies it (PUT). Only keys in the endpoint's schema are applied; Name, Password
/// and anything else are stripped from the user record first.
ClassMethod Save(user As %DynamicObject) As %Status
{
    new $namespace
    set $namespace = "%SYS"
    set name = user.Name
    return:name="" $$$ERROR($$$GeneralError, "User name is required")
    set record = ..SchemaSubset(user)
    if $isobject(..Get(name)) {
        do ..Invoke(..#TYPEPUT, name, record, .sc)
        return sc
    }
    return:user.Password="" $$$ERROR($$$GeneralError, "Password is required for a new user")
    do ..Invoke(..#TYPEPOST, name, {"User": (record), "Password": (user.Password)}, .sc)
    return sc
}

ClassMethod ChangePassword(name As %String, newPassword As %String) As %Status
{
    new $namespace
    set $namespace = "%SYS"
    return:newPassword="" $$$ERROR($$$GeneralError, "New password is required")
    do ..Invoke(..#TYPECHANGEPWD, name, {"NewPassword": (newPassword)}, .sc)
    return sc
}

/// Names of all roles on the instance, for the role pickers on the edit page.
ClassMethod RoleNames() As %DynamicArray
{
    new $namespace
    set $namespace = "%SYS"
    set out = []
    set roles = ..InvokeEndpoint(..#ROLEENDPOINT, ..#TYPELIST, "", {}, .sc)
    return:$$$ISERR(sc) out
    set iter = roles.%GetIterator()
    while iter.%GetNext(.i, .role) {
        do out.%Push(role.Name)
    }
    return out
}

}
