/// Applies the bulk-change dialog's form to every selected user. Goes through
/// Portal.User.Service only, never Security.* or %Api.Admin.* directly, matching how
/// every other Portal.*.Service adapter behaves.
Class PortalExt.UserBulkEdit.Service Extends %RegisteredObject
{

/// Role names for the Add/Remove role pickers; resolved live per request (see
/// optionsClass/optionsMethod on Portal.Ext.Schema's bulk-actions fields), so a role
/// created or renamed after this extension last recompiled still shows up.
ClassMethod RoleNames() As %DynamicArray
{
    return ##class(Portal.User.Service).RoleNames()
}

/// Applies `form`'s tristate flags and role add/remove lists to every row. A tristate
/// key absent from `form` (still "leave unchanged") arrives as JSON null, which
/// %GetTypeOf reports as "null", not "boolean" - so it is simply skipped. Stops at the
/// first failing user and names them, same convention as Portal.WebSession.Service.EndSessions.
ClassMethod Apply(rows As %DynamicArray, form As %DynamicObject) As %Status
{
    set flagKeys = $listbuild("Enabled", "AccountNeverExpires", "PasswordNeverExpires", "ChangePassword")
    set iter = rows.%GetIterator()
    while iter.%GetNext(.i, .row) {
        set name = row.Name
        set user = ##class(Portal.User.Service).Get(name)
        continue:'$isobject(user)
        set ptr = 0
        while $listnext(flagKeys, ptr, key) {
            continue:form.%GetTypeOf(key)'="boolean"
            do user.%Set(key, form.%Get(key), "boolean")
        }
        do ..ApplyRoles(user, "Roles", form.%Get("AddRoles"), form.%Get("RemoveRoles"))
        do ..ApplyRoles(user, "EscalationRoles", form.%Get("AddEscalationRoles"), form.%Get("RemoveEscalationRoles"))
        set sc = ##class(Portal.User.Service).Save(user)
        return:$$$ISERR(sc) $$$ERROR($$$GeneralError, "User " _ name _ ": " _ $system.Status.GetErrorText(sc))
    }
    return $$$OK
}

/// Unions `add` into, then subtracts `remove` from, the user's current `key` array
/// (Roles or EscalationRoles) - add wins when a role is in both lists.
ClassMethod ApplyRoles(user As %DynamicObject, key As %String, add, remove) [ Private ]
{
    set current = user.%Get(key)
    return:'$isobject(current)
    kill roleSet
    set iter = current.%GetIterator()
    while iter.%GetNext(.i, .role) { set roleSet(role) = "" }
    if $isobject(remove) {
        set iter = remove.%GetIterator()
        while iter.%GetNext(.i, .role) { kill roleSet(role) }
    }
    if $isobject(add) {
        set iter = add.%GetIterator()
        while iter.%GetNext(.i, .role) { set roleSet(role) = "" }
    }
    set out = []
    set role = ""
    for {
        set role = $order(roleSet(role))
        quit:role=""
        do out.%Push(role)
    }
    do user.%Set(key, out)
}

}
