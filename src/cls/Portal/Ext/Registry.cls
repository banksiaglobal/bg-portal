/// Discovers and aggregates Portal.Ext.Contribution subclasses.
///
/// Operational state lives in ^Portal.Ext:
///   ^Portal.Ext("disabled", class) = 1        contribution switched off by an admin
///   ^Portal.Ext("incompatible", class) = ver  contribution skipped for targeting another API version
///   ^Portal.Ext("error", class, hook) = text  last failure raised by a hook
///   ^Portal.Ext("collision", hook, id) = class later contribution whose item id was already taken
/// Requesting any page with ?safemode=1 loads no contributions at all, so a broken
/// extension can always be disabled from Portal.Extensions.cls.
Class Portal.Ext.Registry Extends %RegisteredObject
{

Parameter APIVERSION As INTEGER = 1;

ClassMethod SafeMode() As %Boolean
{
    return $isobject($get(%request)) && (%request.Get("safemode") = 1)
}

ClassMethod IsEnabled(class As %String) As %Boolean
{
    return '$get(^Portal.Ext("disabled", class), 0)
}

ClassMethod SetEnabled(class As %String, enabled As %Boolean) As %Status
{
    if enabled {
        kill ^Portal.Ext("disabled", class)
    } else {
        set ^Portal.Ext("disabled", class) = 1
    }
    return $$$OK
}

/// Every concrete contribution class, regardless of state. Used by the admin screen.
ClassMethod AllContributions() As %DynamicArray
{
    set out = []
    set rs = ##class(%ResultSet).%New("%Dictionary.ClassDefinitionQuery:SubclassOf")
    do rs.Execute("Portal.Ext.Contribution")
    while rs.%Next() {
        set class = rs.Get("Name")
        set def = ##class(%Dictionary.CompiledClass).%OpenId(class)
        continue:'$isobject(def)
        continue:def.Abstract
        set version = +$parameter(class, "APIVERSION")
        set item = {
            "class": (class),
            "order": (+$parameter(class, "ORDER")),
            "apiVersion": (version),
            "description": (def.Description)
        }
        do item.%Set("compatible", version = ..#APIVERSION, "boolean")
        do item.%Set("enabled", ..IsEnabled(class), "boolean")
        do out.%Push(item)
    }
    return ..Sort(out)
}

/// Enabled, version-compatible contributions in load order, as a $list of class names.
ClassMethod Contributions() As %List
{
    return:..SafeMode() ""
    set all = ..AllContributions()
    set iter = all.%GetIterator()
    set list = ""
    while iter.%GetNext(.i, .c) {
        if 'c.compatible {
            set ^Portal.Ext("incompatible", c.class) = c.apiVersion
            continue
        }
        continue:'c.enabled
        set list = list _ $listbuild(c.class)
    }
    return list
}

ClassMethod NavItems() As %DynamicArray
{
    return ..Collect("NavItems")
}

ClassMethod TopBarItems() As %DynamicArray
{
    return ..Collect("TopBarItems")
}

ClassMethod UserMenuItems() As %DynamicArray
{
    return ..Collect("UserMenuItems")
}

ClassMethod FooterItems() As %DynamicArray
{
    return ..Collect("FooterItems")
}

ClassMethod Columns(pageId As %String) As %DynamicArray
{
    return ..Collect("Columns", pageId)
}

ClassMethod Actions(pageId As %String) As %DynamicArray
{
    return ..Collect("Actions", pageId)
}

/// Resolves an action by id for server-side dispatch. Re-runs the resource check,
/// so a client cannot invoke an action it was never shown.
ClassMethod FindAction(pageId As %String, actionId As %String) As %DynamicObject
{
    set actions = ..Actions(pageId)
    set iter = actions.%GetIterator()
    while iter.%GetNext(.i, .action) {
        return:action.id=actionId action
    }
    return ""
}

/// Runs one hook across all contributions and merges the results.
ClassMethod Collect(hook As %String, pageId As %String = "") As %DynamicArray
{
    set out = []
    set seen = ""
    set list = ..Contributions()
    set ptr = 0
    set loadOrder = 0
    while $listnext(list, ptr, class) {
        set loadOrder = loadOrder + 1
        // One broken extension must not take the shell down with it.
        try {
            set items = $select(pageId = "": $classmethod(class, hook), 1: $classmethod(class, hook, pageId))
            kill ^Portal.Ext("error", class, hook)
        } catch ex {
            set ^Portal.Ext("error", class, hook) = ex.DisplayString()
            continue
        }
        continue:'$isobject(items)
        set iter = items.%GetIterator()
        while iter.%GetNext(.i, .item) {
            set id = $select(item.id '= "": item.id, 1: item.key)
            continue:id=""
            if $listfind(seen, id) {
                set ^Portal.Ext("collision", hook, id) = class
                continue
            }
            set seen = seen _ $listbuild(id)
            continue:'..Permitted(item.resource)
            set item.source = class
            set item.order = +item.order
            set item.loadOrder = loadOrder
            do out.%Push(item)
        }
    }
    return ..Sort(out)
}

ClassMethod Permitted(resource As %String) As %Boolean
{
    return:resource="" 1
    return $system.Security.Check(resource, "USE")
}

/// Stable sort by order, then load order.
ClassMethod Sort(items As %DynamicArray) As %DynamicArray
{
    set iter = items.%GetIterator()
    while iter.%GetNext(.i, .item) {
        set sorted(+item.order, +item.loadOrder, i) = item
    }
    set out = []
    set order = ""
    for {
        set order = $order(sorted(order))
        quit:order=""
        set load = ""
        for {
            set load = $order(sorted(order, load))
            quit:load=""
            set i = ""
            for {
                set i = $order(sorted(order, load, i), 1, item)
                quit:i=""
                do out.%Push(item)
            }
        }
    }
    return out
}

}
