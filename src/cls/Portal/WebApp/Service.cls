/// Domain adapter over Security.Applications. This is the only place the portal
/// touches %SYS for web applications; pages and extension actions call this,
/// never Security.* directly, so the backend can later be swapped for %Api.Admin
/// without touching any page.
Class Portal.WebApp.Service Extends %RegisteredObject
{

/// Properties the edit page may change. Name and Type are identity and are never modified.
Parameter EDITABLE = "NameSpace,Description,Enabled,DispatchClass,Path,Resource,Timeout,CSRFToken,CookiePath,CSPZENEnabled,IsNameSpaceDefault";

Parameter BOOLEANS = "Enabled,CSRFToken,CSPZENEnabled,IsNameSpaceDefault";

ClassMethod List() As %DynamicArray
{
    new $namespace
    set $namespace = "%SYS"
    set out = []
    set rs = ##class(%ResultSet).%New("Security.Applications:List")
    do rs.Execute("*")
    while rs.%Next() {
        set row = ..Get(rs.Get("Name"))
        do:$isobject(row) out.%Push(row)
    }
    return out
}

ClassMethod Get(name As %String) As %DynamicObject
{
    new $namespace
    set $namespace = "%SYS"
    set sc = ##class(Security.Applications).Get(name, .props)
    return:$$$ISERR(sc) ""
    set row = {"Name": (name)}
    set row.TypeDisplay = ##class(Security.Applications).TypeLogicalToDisplay(props("Type"))
    set key = ""
    for {
        set key = $order(props(key), 1, value)
        quit:key=""
        if ..IsBoolean(key) {
            do row.%Set(key, +value, "boolean")
        } else {
            do row.%Set(key, value)
        }
    }
    return row
}

/// Creates the application when it does not exist, otherwise applies the editable
/// subset of `app`. Unknown or non-editable keys are ignored rather than rejected.
ClassMethod Save(app As %DynamicObject) As %Status
{
    new $namespace
    set $namespace = "%SYS"
    set name = app.Name
    return:name="" $$$ERROR($$$GeneralError, "Application name is required")

    for i = 1:1:$length(..#EDITABLE, ",") {
        set key = $piece(..#EDITABLE, ",", i)
        continue:'app.%IsDefined(key)
        set props(key) = $select(..IsBoolean(key): +app.%Get(key), 1: app.%Get(key))
    }

    if ##class(Security.Applications).Exists(name) {
        return ##class(Security.Applications).Modify(name, .props)
    }
    return:props("NameSpace")="" $$$ERROR($$$GeneralError, "Namespace is required for a new application")
    return ##class(Security.Applications).Create(name, .props)
}

ClassMethod Delete(row As %DynamicObject) As %Status
{
    new $namespace
    set $namespace = "%SYS"
    return ##class(Security.Applications).Delete(row.Name)
}

ClassMethod Enable(row As %DynamicObject) As %Status
{
    return ..SetEnabled(row.Name, 1)
}

ClassMethod Disable(row As %DynamicObject) As %Status
{
    return ..SetEnabled(row.Name, 0)
}

ClassMethod SetEnabled(name As %String, enabled As %Boolean) As %Status
{
    new $namespace
    set $namespace = "%SYS"
    set props("Enabled") = enabled
    return ##class(Security.Applications).Modify(name, .props)
}

ClassMethod IsBoolean(key As %String) As %Boolean
{
    return $listfind($listfromstring(..#BOOLEANS), key) > 0
}

}
