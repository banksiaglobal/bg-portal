/// Discovers and aggregates Portal.Ext.Contribution subclasses.
///
/// Operational state lives in ^Portal.Ext:
///   ^Portal.Ext("installed", class) = $lb(version, $h)  first seen (OnInstall ran); version is updated by OnUpgrade
///   ^Portal.Ext("retired", class) = $h                   OnUninstall ran; the class is ignored until reinstalled
///   ^Portal.Ext("disabled", class) = 1                   contribution switched off by an admin
///   ^Portal.Ext("incompatible", class) = ver             contribution skipped for targeting another API version
///   ^Portal.Ext("error", class, slot|hook) = text        last failure raised while collecting a slot or running a lifecycle hook
///   ^Portal.Ext("collision", slot, id) = class           later contribution whose item id (or replace target) was already taken
///   ^Portal.Ext("override", slot, targetId) = $lb(class, newId)  item replaced (newId) or hidden ("") by class
///   ^Portal.Ext("warning", class, slot) = text          items kept despite unknown keys (Portal.Ext.Schema)
///   ^Portal.Ext("cache", fingerprint, class, slot) = json  validated raw output of Contribute(slot), see below
/// Requesting any page with ?safemode=1 (as a %All user) loads no contributions at all,
/// so a broken extension can always be disabled from Portal.Extensions.cls.
///
/// Cache: discovery (one %Dictionary query per request) yields a fingerprint of the
/// contribution set - every concrete class with its compile time, the disabled/retired
/// state and APIVERSION. The raw, validated output of each Contribute(slot) is kept
/// under that fingerprint, so a page render calls no hook at all once warm; the
/// per-user parts (resource filter, replaces/hide, sort) still run on every request.
/// A recompiled or newly disabled class changes the fingerprint and the old entries are
/// dropped when the new one is first seen. A hook that throws is not cached, so the
/// next request retries it. Sync, SetEnabled, Uninstall, Reinstall and ClearCache()
/// empty the cache; ?nocache=1 bypasses it for one request and
/// ^Portal.Config("EXT_CACHE") = 0 turns it off. Within one request the fingerprint
/// and class list are memoised in %PortalExt (keyed by a token stored on %request).
Class Portal.Ext.Registry Extends %RegisteredObject
{

Parameter APIVERSION As INTEGER = 2;

/// Only a user holding %All may request it; for anyone else ?safemode=1 is ignored.
ClassMethod SafeMode() As %Boolean
{
    return $isobject($get(%request)) && (%request.Get("safemode") = 1) && ..HasRole("%All")
}

ClassMethod HasRole(role As %String) As %Boolean
{
    return:role="" 1
    return $listfind($listfromstring($roles), role) > 0
}

/// False with ?nocache=1 on the request or ^Portal.Config("EXT_CACHE") = 0.
ClassMethod CacheEnabled() As %Boolean
{
    return:$get(^Portal.Config("EXT_CACHE"), 1)=0 0
    return:($isobject($get(%request)) && (%request.Get("nocache") = 1)) 0
    return 1
}

/// Drops every cached Contribute() result and the per-request memo.
ClassMethod ClearCache()
{
    kill ^Portal.Ext("cache"), %PortalExt
}

/// Discovery for this request, memoised: {"classes": $list, "fingerprint": ""|hash}.
/// The memo lives in %PortalExt under a token the first call stores on %request, so a
/// new request (a new %request object, no token) always rediscovers; outside a request
/// nothing is memoised. The fingerprint is "" when the cache is off.
ClassMethod Context() As %DynamicObject
{
    set token = ""
    if $isobject($get(%request)) {
        set token = %request.Get("%PortalExt")
        if token = "" {
            set token = $job _ "^" _ $zhorolog _ "^" _ $increment(%PortalExt("seq"))
            do %request.Set("%PortalExt", token)
        }
        return:$data(%PortalExt(token), ctx) ctx
    }
    set ctx = ..Discover()
    if token '= "" {
        kill %PortalExt
        set %PortalExt(token) = ctx
    }
    return ctx
}

/// One pass over the compiled Portal.Ext.Contribution subclasses: the concrete class
/// list and, when caching is on, the fingerprint (sorted class^TimeChanged pairs, the
/// disabled and retired state, APIVERSION), with stale cache generations dropped.
ClassMethod Discover() As %DynamicObject
{
    set list = ""
    set parts = ""
    set rs = ##class(%ResultSet).%New("%Dictionary.ClassDefinitionQuery:SubclassOf")
    do rs.Execute("Portal.Ext.Contribution")
    while rs.%Next() {
        set class = rs.Get("Name")
        set def = ##class(%Dictionary.CompiledClass).%OpenId(class)
        continue:'$isobject(def)
        continue:def.Abstract
        set sorted(class) = def.TimeChanged
    }
    set class = ""
    for {
        set class = $order(sorted(class), 1, changed)
        quit:class=""
        set list = list _ $listbuild(class)
        set parts = parts _ class _ "^" _ changed _ "|"
    }
    set fingerprint = ""
    if ..CacheEnabled() {
        for state = "disabled", "retired" {
            set class = ""
            for {
                set class = $order(^Portal.Ext(state, class))
                quit:class=""
                set parts = parts _ state _ ":" _ class _ "|"
            }
        }
        set parts = parts _ "api" _ ..#APIVERSION
        set fingerprint = $zconvert(##class(%xsd.hexBinary).LogicalToXSD($system.Encryption.SHA1Hash(parts)), "L")
        if '$data(^Portal.Ext("cache", fingerprint)) {
            kill ^Portal.Ext("cache")
            set ^Portal.Ext("cache", fingerprint) = $horolog
        }
    }
    return {"classes": (list), "fingerprint": (fingerprint)}
}

ClassMethod IsEnabled(class As %String) As %Boolean
{
    return '$get(^Portal.Ext("disabled", class), 0)
}

ClassMethod IsRetired(class As %String) As %Boolean
{
    return $data(^Portal.Ext("retired", class))
}

/// Switches a contribution on or off, running OnEnable/OnDisable first. When the hook
/// fails the switch stays where it was and the error is recorded against the class.
ClassMethod SetEnabled(class As %String, enabled As %Boolean) As %Status
{
    return:enabled=..IsEnabled(class) $$$OK
    set hook = $select(enabled: "OnEnable", 1: "OnDisable")
    set sc = ..RunHook(class, hook)
    return:$$$ISERR(sc) sc
    if enabled {
        kill ^Portal.Ext("disabled", class)
    } else {
        set ^Portal.Ext("disabled", class) = 1
    }
    do ..ClearCache()
    return $$$OK
}

/// Runs one lifecycle hook, isolating exceptions, and keeps its last error in ^Portal.Ext.
ClassMethod RunHook(class As %String, hook As %String, arg As %String = "", hasArg As %Boolean = 0) As %Status
{
    try {
        set sc = $select(hasArg: $classmethod(class, hook, arg), 1: $classmethod(class, hook))
    } catch ex {
        set sc = ex.AsStatus()
    }
    if $$$ISERR(sc) {
        set ^Portal.Ext("error", class, hook) = $system.Status.GetErrorText(sc)
    } else {
        kill ^Portal.Ext("error", class, hook)
    }
    return sc
}

/// Concrete, compiled Portal.Ext.Contribution subclasses, as a $list (memoised per request).
ClassMethod DiscoverClasses() As %List
{
    return ..Context().classes
}

/// Reconciles the installed state with the compiled classes: runs OnInstall for classes
/// seen for the first time, OnUpgrade when their VERSION changed, and forgets state of
/// classes that no longer exist. Runs on every discovery and can be called from ZPM
/// lifecycle hooks after a module was loaded.
ClassMethod Sync() As %Status
{
    do ..ClearCache()
    return ..SyncClasses(..DiscoverClasses())
}

ClassMethod SyncClasses(classes As %List) As %Status
{
    set ptr = 0
    while $listnext(classes, ptr, class) {
        continue:..IsRetired(class)
        set version = $parameter(class, "VERSION")
        if '$data(^Portal.Ext("installed", class), installed) {
            do ..RunHook(class, "OnInstall")
            set ^Portal.Ext("installed", class) = $listbuild(version, $horolog)
        } elseif $listget(installed, 1) '= version {
            do ..RunHook(class, "OnUpgrade", $listget(installed, 1), 1)
            set ^Portal.Ext("installed", class) = $listbuild(version, $listget(installed, 2))
        }
    }
    for state = "installed", "retired", "disabled", "incompatible", "error", "warning" {
        set class = ""
        for {
            set class = $order(^Portal.Ext(state, class))
            quit:class=""
            kill:'$listfind(classes, class) ^Portal.Ext(state, class)
        }
    }
    return $$$OK
}

/// Runs OnUninstall and drops all the contribution's state. With `retire` (the admin
/// screen) the class stays and discovery ignores it until Reinstall; a ZPM module's
/// uninstall hook passes 0 because the code is about to be removed anyway, so a later
/// `zpm "load"` installs it afresh.
ClassMethod Uninstall(class As %String, retire As %Boolean = 1) As %Status
{
    return:'$listfind(..DiscoverClasses(), class) $$$ERROR($$$GeneralError, "'" _ class _ "' is not a contribution")
    set sc = ..RunHook(class, "OnUninstall")
    return:$$$ISERR(sc) sc
    kill ^Portal.Ext("installed", class), ^Portal.Ext("disabled", class), ^Portal.Ext("incompatible", class), ^Portal.Ext("error", class), ^Portal.Ext("warning", class), ^Portal.Ext("retired", class)
    set:retire ^Portal.Ext("retired", class) = $horolog
    do ..ClearCache()
    return $$$OK
}

/// Brings a retired contribution back; OnInstall runs again on the next Sync.
ClassMethod Reinstall(class As %String) As %Status
{
    kill ^Portal.Ext("retired", class)
    return ..Sync()
}

/// The installed ZPM module owning `class`, as {name, version, source}, or "" when the
/// package manager is absent or the class belongs to no module.
ClassMethod ModuleFor(class As %String) As %DynamicObject
{
    try {
        return:'##class(%Dictionary.CompiledClass).%ExistsId("%IPM.Storage.Module") ""
        set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM %IPM_Storage.ModuleItem")
        while rs.%Next() {
            set module = ##class(%IPM.Storage.Module).%OpenId(rs.ID)
            continue:'$isobject(module)
            set key = ""
            for {
                set resource = module.Resources.GetNext(.key)
                quit:key=""
                set name = resource.Name
                set kind = $zconvert($piece(name, ".", *), "U")
                set base = $piece(name, ".", 1, $length(name, ".") - 1)
                set owns = $select(kind = "PKG": $extract(class, 1, $length(base) + 1) = (base _ "."), kind = "CLS": base = class, 1: 0)
                continue:'owns
                return {"name": (module.Name), "version": (module.VersionString), "source": (module.Root)}
            }
        }
    } catch ex {
    }
    return ""
}

/// Every concrete contribution class with its manifest, module and state. Used by the
/// admin screen (manifests and the IPM lookup are too heavy for the per-request path).
ClassMethod AllContributions() As %DynamicArray
{
    set out = []
    set classes = ..DiscoverClasses()
    do ..SyncClasses(classes)
    set ptr = 0
    while $listnext(classes, ptr, class) {
        try {
            set item = $classmethod(class, "Manifest")
            kill ^Portal.Ext("error", class, "Manifest")
        } catch ex {
            set ^Portal.Ext("error", class, "Manifest") = ex.DisplayString()
            set item = {"id": (class), "name": (class), "version": "", "requires": [], "description": ""}
        }
        set item.class = class
        set item.order = +$parameter(class, "ORDER")
        set item.apiVersion = +$parameter(class, "APIVERSION")
        set item.module = ..ModuleFor(class)
        set installed = $get(^Portal.Ext("installed", class))
        set item.installedAt = $select(installed = "": "", 1: $zdatetime($listget(installed, 2), 3))
        do item.%Set("compatible", item.apiVersion = ..#APIVERSION, "boolean")
        do item.%Set("enabled", ..IsEnabled(class), "boolean")
        do item.%Set("retired", ..IsRetired(class), "boolean")
        do out.%Push(item)
    }
    return ..Sort(out)
}

/// Enabled, installed, version-compatible contributions in load order, as a $list of
/// class names. Discovery runs Sync, so a freshly compiled class gets its OnInstall here.
ClassMethod Contributions() As %List
{
    return:..SafeMode() ""
    set ctx = ..Context()
    set classes = ctx.classes
    if 'ctx.synced {
        do ..SyncClasses(classes)
        do ctx.%Set("synced", 1, "boolean")
    }
    set ptr = 0
    while $listnext(classes, ptr, class) {
        continue:..IsRetired(class)
        set apiVersion = +$parameter(class, "APIVERSION")
        if apiVersion '= ..#APIVERSION {
            set ^Portal.Ext("incompatible", class) = apiVersion
            continue
        }
        continue:'..IsEnabled(class)
        set sorted(+$parameter(class, "ORDER"), class) = ""
    }
    set list = ""
    set order = ""
    for {
        set order = $order(sorted(order))
        quit:order=""
        set class = ""
        for {
            set class = $order(sorted(order, class))
            quit:class=""
            set list = list _ $listbuild(class)
        }
    }
    return list
}

/// True when `class` can be emitted as a Bloom component. Failures are recorded
/// against the contributing class so the Extensions screen shows them.
ClassMethod ValidComponent(class As %String, source As %String, where As %String) As %Boolean
{
    set ok = 0
    try {
        set ok = ##class(%Dictionary.CompiledClass).%ExistsId(class) && $classmethod(class, "%Extends", "Banksia.Bloom.Component")
    } catch ex {
        set ok = 0
    }
    set:'ok ^Portal.Ext("error", source, where) = "'" _ class _ "' is not a compiled Banksia.Bloom.Component subclass"
    return ok
}

/// Resolves an item by id in a slot for server-side dispatch. Re-runs the resource
/// check, so a client cannot invoke an action it was never shown.
ClassMethod FindItem(slot As %String, id As %String) As %DynamicObject
{
    set items = ..Collect(slot)
    set iter = items.%GetIterator()
    while iter.%GetNext(.i, .item) {
        return:item.id=id item
    }
    return ""
}

/// Runs Contribute(slot) across all contributions and merges the results. Precedence:
///   (a) collect in load order, (b) drop id collisions, (c) apply `replaces`,
///   (d) apply `hide`, (e) filter by resource and role, (f) sort by order, then load order.
/// A replacement takes the target's position (order and load order unless it sets its
/// own `order`) and is still subject to its own `resource`: when the replacer lacks it
/// the item is simply absent, because the target is already gone (fail closed).
/// Overrides are recorded in ^Portal.Ext("override", slot, targetId) = $lb(class, newId)
/// (newId "" for a hide) and shown on the Extensions screen.
ClassMethod Collect(slot As %String) As %DynamicArray
{
    kill ^Portal.Ext("override", slot)
    set list = ..Contributions()
    set fingerprint = ..Context().fingerprint
    set ptr = 0
    set loadOrder = 0
    set n = 0
    while $listnext(list, ptr, class) {
        set loadOrder = loadOrder + 1
        set items = ..RawItems(class, slot, fingerprint)
        continue:'$isobject(items)
        set iter = items.%GetIterator()
        while iter.%GetNext(.i, .item) {
            set item.source = class
            set item.loadOrder = loadOrder
            if item.hide '= "" {
                set hides($increment(hides)) = item
                continue
            }
            set id = $select(item.id '= "": item.id, 1: item.key)
            continue:id=""
            if item.replaces '= "" {
                set replacements($increment(replacements)) = item
                continue
            }
            set item.order = +item.order
            do ..Place(slot, item, .items, .ids, .n)
        }
    }
    // (c) replacements win regardless of load order; a second replacer of the same target collides
    for r = 1:1:$get(replacements) {
        set item = replacements(r)
        set target = item.replaces
        set id = $select(item.id '= "": item.id, 1: item.key)
        if $data(replaced(target)) {
            set ^Portal.Ext("collision", slot, target) = item.source
            continue
        }
        if '$data(ids(target), at) {
            set ^Portal.Ext("error", item.source, slot) = "replaces '" _ target _ "' but no such item"
            set item.order = +item.order
            do ..Place(slot, item, .items, .ids, .n)
            continue
        }
        set old = items(at)
        set item.order = $select(item.%IsDefined("order"): +item.order, 1: old.order)
        set item.loadOrder = old.loadOrder
        kill items(at), ids(target)
        set replaced(target) = ""
        set ^Portal.Ext("override", slot, target) = $listbuild(item.source, id)
        do ..Place(slot, item, .items, .ids, .n)
    }
    // (d) hides
    for h = 1:1:$get(hides) {
        set item = hides(h)
        set target = item.hide
        if '$data(ids(target), at) {
            set ^Portal.Ext("error", item.source, slot) = "hides '" _ target _ "' but no such item"
            continue
        }
        kill items(at), ids(target)
        set ^Portal.Ext("override", slot, target) = $listbuild(item.source, "")
    }
    // (e) resource filter
    set out = []
    set k = ""
    for {
        set k = $order(items(k), 1, item)
        quit:k=""
        continue:'..Permitted(item.resource)
        continue:'..HasRole(item.role)
        do out.%Push(item)
    }
    return ..Sort(out)
}

/// The validated output of class.Contribute(slot), from ^Portal.Ext("cache") when the
/// fingerprint has it, else from the hook: exceptions are recorded against the class and
/// slot and nothing is cached (so the next request retries); items that fail
/// Portal.Ext.Schema are dropped with the first reason in ^Portal.Ext("error", class, slot),
/// unknown keys keep the item and go to ^Portal.Ext("warning", class, slot).
/// One broken extension must not take the shell down with it.
ClassMethod RawItems(class As %String, slot As %String, fingerprint As %String = "") As %DynamicArray
{
    if fingerprint '= "", $data(^Portal.Ext("cache", fingerprint, class, slot), json) {
        return:json="" ""
        return [].%FromJSON(json)
    }
    try {
        set items = $classmethod(class, "Contribute", slot)
        kill ^Portal.Ext("error", class, slot), ^Portal.Ext("warning", class, slot)
    } catch ex {
        set ^Portal.Ext("error", class, slot) = ex.DisplayString()
        return ""
    }
    if '$isobject(items) || 'items.%IsA("%Library.DynamicArray") {
        set:$isobject(items) ^Portal.Ext("error", class, slot) = "Contribute() must return a %DynamicArray"
        set:fingerprint'="" ^Portal.Ext("cache", fingerprint, class, slot) = ""
        return ""
    }
    set out = []
    set (errors, warnings) = 0
    set iter = items.%GetIterator()
    while iter.%GetNext(.i, .item) {
        set ok = ##class(Portal.Ext.Schema).Validate(slot, item, .reason, .warning)
        set id = $select('$isobject(item): "#" _ i, item.hide '= "": "hide " _ item.hide, item.id '= "": item.id, item.key '= "": item.key, 1: "#" _ i)
        if 'ok {
            set errors = errors + 1
            set:errors=1 ^Portal.Ext("error", class, slot) = "item '" _ id _ "': " _ reason
            continue
        }
        if warning '= "" {
            set warnings = warnings + 1
            set:warnings=1 ^Portal.Ext("warning", class, slot) = "item '" _ id _ "': " _ warning
        }
        do out.%Push(item)
    }
    set:errors>1 ^Portal.Ext("error", class, slot) = ^Portal.Ext("error", class, slot) _ " (+" _ (errors - 1) _ " more invalid item" _ $select(errors > 2: "s", 1: "") _ ")"
    set:warnings>1 ^Portal.Ext("warning", class, slot) = ^Portal.Ext("warning", class, slot) _ " (+" _ (warnings - 1) _ " more)"
    set:fingerprint'="" ^Portal.Ext("cache", fingerprint, class, slot) = $select(out.%Size(): out.%ToJSON(), 1: "")
    return out
}

/// Adds an item to the working set unless its id is already taken (recorded as a collision).
ClassMethod Place(slot As %String, item As %DynamicObject, ByRef items, ByRef ids, ByRef n)
{
    set id = $select(item.id '= "": item.id, 1: item.key)
    if $data(ids(id)) {
        set ^Portal.Ext("collision", slot, id) = item.source
        return
    }
    set n = n + 1
    set items(n) = item
    set ids(id) = n
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
