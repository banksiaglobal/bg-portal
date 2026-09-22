/// Item schemas per slot kind, used by Portal.Ext.Registry to validate what a
/// Contribute(slot) hook returns before the items are cached, and by Portal.Ext.Slots
/// to render the extension-points reference (Portal.Extensions.cls, Markdown()).
///
/// A schema is a %DynamicObject descriptor:
///   {"kind": "actions", "keys": {"<key>": {"type", "required", "enum", "doc"}, ...},
///    "conditional": [{"when": {"<key>": "<value>"}, "required": ["<key>", ...]}],
///    "example": {...}}
/// Value types: string | number | boolean | array | object | when | any. `when` is a
/// string checked with CheckWhen (balanced quotes and parentheses, known tokens only);
/// the real evaluator is client-side in Portal.Page.evalWhen.
///
/// Validation outcome: a missing required key, a wrong type, a value outside the
/// enumeration or a malformed `when` drops the item (error); an unknown key keeps the
/// item and is reported as a warning. The keys in COMMON are accepted on every item.
Class Portal.Ext.Schema Extends %RegisteredObject
{

/// Keys every item may carry, whatever the slot: the override and placement mechanics,
/// plus what the registry stamps on an item itself (`source`, `loadOrder`).
Parameter COMMON = "replaces,hide,when,resource,role,order,source,loadOrder";

Parameter KINDS = "items,columns,actions,bulk-actions,fields,widgets,head";

Parameter SEVERITIES = "primary,secondary,success,info,warn,danger,contrast,help";

Parameter FIELDTYPES = "text,number,password,date,textarea,select,multiselect,toggle,perms";

Parameter COLUMNTYPES = "text,boolean,tag,mono";

/// The slot kind of a slot id: shell.* is "items", page.<id>.<kind>[.<name>] is the kind.
ClassMethod KindOf(slot As %String) As %String
{
    return:slot="shell.head" "head"
    return:$piece(slot, ".", 1)="shell" "items"
    set kind = $piece(slot, ".", *)
    set:$piece(slot, ".", *-1)="widgets" kind = "widgets"
    return $select($listfind($listfromstring(..#KINDS), kind): kind, 1: "")
}

/// Schema of a slot id; shell.footer relaxes `url` (text-only footer entries are allowed).
ClassMethod ForSlot(slot As %String) As %DynamicObject
{
    set schema = ..For(..KindOf(slot))
    return:'$isobject(schema) ""
    if slot = "shell.footer" {
        do schema.keys.%Remove("group")
        do schema.keys.%Remove("icon")
        do schema.keys.url.%Set("required", 0, "boolean")
        set schema.example = {"id": "acme.docs", "label": "Acme docs", "url": "https://acme.example/docs", "order": 100}
    }
    if slot = "shell.user-menu" {
        do schema.keys.%Remove("group")
        set schema.example = {"id": "acme.profile", "label": "My profile", "icon": "pi pi-user", "url": "Acme.Portal.Profile.cls", "order": 50}
    }
    if slot = "shell.topbar" {
        do schema.keys.%Remove("group")
        set schema.example = {"id": "acme.status", "label": "Status", "icon": "pi pi-heart", "url": "Acme.Portal.Status.cls", "order": 10}
    }
    return schema
}

/// Schema of a slot kind (items | columns | actions | bulk-actions | fields | widgets), or "" for an unknown kind.
ClassMethod For(kind As %String) As %DynamicObject
{
    set severities = ..List(..#SEVERITIES)
    if kind = "items" {
        return {
            "kind": "items",
            "keys": {
                "id": {"type": "string", "required": true, "doc": "Unique within the slot; prefix with the extension name."},
                "label": {"type": "string", "required": true, "doc": "Text shown."},
                "url": {"type": "string", "required": true, "doc": "Link target, relative to the portal application or absolute."},
                "icon": {"type": "string", "doc": "PrimeIcons class, e.g. pi pi-star."},
                "group": {"type": "string", "doc": "Sidebar heading the entry sits under (shell.nav only)."},
                "order": {"type": "number", "doc": "Sort key; items with equal order keep load order."},
                "resource": {"type": "string", "doc": "IRIS resource the user needs USE on; the item is not emitted otherwise."},
                "role": {"type": "string", "doc": "IRIS role the user must hold; the item is not emitted otherwise."}
            },
            "example": {"id": "acme.queue", "label": "Queue", "icon": "pi pi-inbox", "url": "Acme.Portal.Queue.cls", "group": "Acme", "order": 300, "resource": "%Acme_Queue"}
        }
    }
    if kind = "columns" {
        return {
            "kind": "columns",
            "keys": {
                "key": {"type": "string", "required": true, "doc": "Row field the column reads; also the column id."},
                "label": {"type": "string", "required": true, "doc": "Header text."},
                "order": {"type": "number", "doc": "Position among the page's columns (core columns are 10, 20, ...)."},
                "sortable": {"type": "boolean"},
                "type": {"type": "string", "enum": (..List(..#COLUMNTYPES)), "doc": "Built-in renderer; default text."},
                "severities": {"type": "object", "doc": "For type tag: {value: severity}."},
                "class": {"type": "string", "doc": "With method: ClassMethod(row As %DynamicObject) As %String computed per row server-side."},
                "method": {"type": "string"},
                "component": {"type": "string", "doc": "Banksia.Bloom.Component (PROPS = \"row,col\") rendering the cell."},
                "when": {"type": "when", "doc": "Display expression; scope {rows}."},
                "resource": {"type": "string"}
            },
            "conditional": [{"when": {"type": "tag"}, "required": ["severities"]}],
            "example": {"key": "Owner", "label": "Owner", "order": 35, "class": "Acme.Portal.Ext", "method": "Owner"}
        }
    }
    if kind = "actions" {
        return {
            "kind": "actions",
            "keys": {
                "id": {"type": "string", "required": true, "doc": "Action id; written to ^Portal.Audit for server actions."},
                "label": {"type": "string", "required": true},
                "kind": {"type": "string", "required": true, "enum": ["navigate", "server"], "doc": "navigate opens url; server calls class/method with the row."},
                "order": {"type": "number"},
                "icon": {"type": "string"},
                "severity": {"type": "string", "enum": (severities), "doc": "Button severity."},
                "resource": {"type": "string", "doc": "Re-checked on invocation for server actions."},
                "confirm": {"type": "boolean", "doc": "Ask before running."},
                "when": {"type": "when", "doc": "Display expression; scope {row}."},
                "url": {"type": "string", "doc": "kind navigate: {Field} placeholders are URL-encoded, {Field|raw} is not."},
                "class": {"type": "string", "doc": "kind server: ClassMethod(row As %DynamicObject) As %Status."},
                "method": {"type": "string"}
            },
            "conditional": [
                {"when": {"kind": "server"}, "required": ["class", "method"]},
                {"when": {"kind": "navigate"}, "required": ["url"]}
            ],
            "example": {"id": "acme.archive", "label": "Archive", "kind": "server", "icon": "pi pi-box", "severity": "warn", "confirm": true, "class": "Acme.Portal.Ext", "method": "Archive", "when": "!row.Enabled", "order": 50}
        }
    }
    if kind = "bulk-actions" {
        return {
            "kind": "bulk-actions",
            "keys": {
                "id": {"type": "string", "required": true},
                "label": {"type": "string", "required": true},
                "order": {"type": "number"},
                "icon": {"type": "string"},
                "severity": {"type": "string", "enum": (severities)},
                "resource": {"type": "string", "doc": "Re-checked on invocation."},
                "confirm": {"type": "boolean"},
                "when": {"type": "when", "doc": "Display expression; scope {rows} (the selection)."},
                "class": {"type": "string", "required": true, "doc": "ClassMethod(rows As %DynamicArray) As %Status."},
                "method": {"type": "string", "required": true}
            },
            "example": {"id": "acme.export", "label": "Export", "icon": "pi pi-download", "confirm": true, "class": "Acme.Portal.Ext", "method": "Export", "when": "rows.length <= 50", "order": 10}
        }
    }
    if kind = "fields" {
        return {
            "kind": "fields",
            "keys": {
                "key": {"type": "string", "required": true, "doc": "Property on the form object; the value never reaches the page's Save."},
                "label": {"type": "string", "required": true},
                "type": {"type": "string", "enum": (..List(..#FIELDTYPES)), "doc": "Input type; default text."},
                "order": {"type": "number"},
                "section": {"type": "string", "doc": "Card the field renders in; new names create a card."},
                "colSpan": {"type": "number", "doc": "1 or 2 grid columns."},
                "placeholder": {"type": "string"},
                "help": {"type": "string", "doc": "Hint under the input."},
                "options": {"type": "any", "doc": "select/multiselect: array of values, or the name of a page property holding one."},
                "clearable": {"type": "boolean"},
                "disabledIf": {"type": "object", "doc": "{field, equals} evaluated against the object."},
                "resource": {"type": "string"},
                "when": {"type": "when", "doc": "Display expression; scope {obj, isNew}."},
                "newOnly": {"type": "boolean"},
                "existingOnly": {"type": "boolean"},
                "class": {"type": "string", "doc": "Persistence: loader(name) As %String seeds it, method(name, value) As %Status stores it."},
                "loader": {"type": "string"},
                "method": {"type": "string"}
            },
            "example": {"key": "CostCentre", "label": "Cost centre", "section": "Acme", "order": 500, "class": "Acme.Portal.Ext", "loader": "LoadCostCentre", "method": "SaveCostCentre"}
        }
    }
    if kind = "head" {
        return {
            "kind": "head",
            "keys": {
                "id": {"type": "string", "required": true, "doc": "Unique within the slot; prefix with the extension name."},
                "url": {"type": "string", "doc": "Stylesheet URL, relative to the portal application or absolute; emitted as a <link>."},
                "css": {"type": "string", "doc": "Inline CSS, emitted as a <style> block."},
                "src": {"type": "string", "doc": "Script URL, relative to the portal application or absolute; emitted as a <script src>."},
                "js": {"type": "string", "doc": "Inline JavaScript, emitted as a <script> block. Runs once, at head-parse time, before the app mounts."},
                "page": {"type": "string", "doc": "PAGEID to scope the item to; empty applies it to every page."},
                "order": {"type": "number", "doc": "Sort key; items with equal order keep load order."}
            },
            "example": {"id": "acme.theme", "css": ".p-card { border-radius: 0; }", "order": 100}
        }
    }
    if kind = "widgets" {
        return {
            "kind": "widgets",
            "keys": {
                "id": {"type": "string", "required": true},
                "component": {"type": "string", "required": true, "doc": "Banksia.Bloom.Component (PROPS = \"ctx\") rendered in a Card."},
                "order": {"type": "number"},
                "title": {"type": "string", "doc": "Card title; untitled when empty."},
                "width": {"type": "number", "enum": [1, 2, 3], "doc": "Grid columns spanned (ignored by stacked slots)."},
                "when": {"type": "when", "doc": "Display expression; scope {ctx}."},
                "resource": {"type": "string"}
            },
            "example": {"id": "acme.queue", "component": "Acme.Portal.QueueWidget", "title": "Queue depth", "width": 2, "order": 50}
        }
    }
    return ""
}

/// Validates one item against the schema of a slot. Returns 1 when the item may be used;
/// `reason` carries the first error (item dropped), `warning` the first warning (item kept).
/// A pure hide ({"hide": "<id>"}) only needs a non-empty string.
ClassMethod Validate(slot As %String, item As %DynamicObject, Output reason As %String, Output warning As %String) As %Boolean
{
    set (reason, warning) = ""
    return:'$isobject(item)||'item.%IsA("%Library.DynamicObject") ..Fail(.reason, "not an object")
    if item.%IsDefined("hide") {
        return:item.%GetTypeOf("hide")'="string"||(item.hide="") ..Fail(.reason, "'hide' must name an item id")
        return 1
    }
    set schema = ..ForSlot(slot)
    return:'$isobject(schema) 1
    if (schema.kind = "head") && (item.url = "") && (item.css = "") && (item.src = "") && (item.js = "") {
        return ..Fail(.reason, "needs one of 'url', 'css', 'src', 'js'")
    }
    set keys = schema.keys
    set common = $listfromstring(..#COMMON)
    // required keys
    set iter = keys.%GetIterator()
    while iter.%GetNext(.key, .spec) {
        continue:'spec.required
        return:'item.%IsDefined(key)||(item.%GetTypeOf(key)="null") ..Fail(.reason, "missing required '" _ key _ "'")
    }
    // conditional requirements (kind: server needs class/method, ...)
    if $isobject(schema.conditional) {
        set citer = schema.conditional.%GetIterator()
        while citer.%GetNext(.c, .cond) {
            set applies = 1
            set witer = cond.when.%GetIterator()
            while witer.%GetNext(.key, .value) {
                set:item.%Get(key)'=value applies = 0
            }
            continue:'applies
            set riter = cond.required.%GetIterator()
            while riter.%GetNext(.r, .key) {
                return:'item.%IsDefined(key)||(item.%Get(key)="") ..Fail(.reason, "missing '" _ key _ "' (required with " _ ..Describe(cond.when) _ ")")
            }
        }
    }
    // types, enumerations, unknown keys
    set iter = item.%GetIterator()
    while iter.%GetNext(.key, .value) {
        set spec = keys.%Get(key)
        if '$isobject(spec) {
            if '$listfind(common, key) {
                set:warning="" warning = "unknown key '" _ key _ "'"
                continue
            }
            set spec = ..CommonSpec(key)
        }
        set actual = item.%GetTypeOf(key)
        continue:actual="null"
        set problem = ..CheckType(spec.type, actual, value)
        return:problem'="" ..Fail(.reason, "'" _ key _ "' " _ problem)
        if $isobject(spec.enum) {
            set allowed = ""
            set eiter = spec.enum.%GetIterator()
            while eiter.%GetNext(.e, .ev) { set allowed = allowed _ $listbuild(ev) }
            return:'$listfind(allowed, value) ..Fail(.reason, "'" _ key _ "' must be one of " _ $listtostring(allowed, "|") _ ", not '" _ value _ "'")
        }
    }
    return 1
}

/// A comma-separated list as a %DynamicArray (enumerations in the descriptors).
ClassMethod List(csv As %String) As %DynamicArray
{
    set out = []
    for i = 1:1:$length(csv, ",") {
        do out.%Push($piece(csv, ",", i))
    }
    return out
}

ClassMethod CommonSpec(key As %String) As %DynamicObject
{
    return:key="when" {"type": "when"}
    return:key="order" {"type": "number"}
    return:key="loadOrder" {"type": "number"}
    return {"type": "string"}
}

/// "" when `value` (of JSON type `actual`) fits `type`, otherwise the problem.
ClassMethod CheckType(type As %String, actual As %String, value) As %String
{
    return:type="any" ""
    if type = "when" {
        return:actual'="string" "must be a string expression"
        set problem = ..CheckWhen(value)
        return $select(problem = "": "", 1: "is not a valid when expression: " _ problem)
    }
    if type = "string" {
        return:(actual="string")||(actual="number")||(actual="boolean") ""
        return "must be a string, not " _ actual
    }
    if type = "number" {
        return:actual="number" ""
        return:(actual="string")&&(value?.1"-".N.1".".N)&&(value'="")&&(value'="-") ""
        return "must be a number, not " _ actual
    }
    if type = "boolean" {
        return:actual="boolean" ""
        return:(actual="number")&&((value=0)||(value=1)) ""
        return "must be a boolean, not " _ actual
    }
    return:(type="array")&&(actual'="array") "must be an array, not " _ actual
    return:(type="object")&&(actual'="object") "must be an object, not " _ actual
    return ""
}

/// Cheap syntax check of a `when` expression: known tokens only, balanced quotes and
/// parentheses, no empty expression. Returns "" when it passes, else the problem.
ClassMethod CheckWhen(expr As %String) As %String
{
    return:$zstrip(expr, "<>W")="" "empty"
    set depth = 0
    set pos = 1
    set len = $length(expr)
    set matcher = ##class(%Regex.Matcher).%New("^(?:\d+(?:\.\d+)?|[A-Za-z_$][\w$]*(?:\.[A-Za-z_$][\w$]*)*|===|!==|==|!=|<=|>=|&&|\|\||[!<>()])")
    while pos <= len {
        set ch = $extract(expr, pos)
        if ch = " " { set pos = pos + 1  continue }
        if (ch = "'") || (ch = """") {
            set end = pos + 1
            while end <= len {
                set c = $extract(expr, end)
                if c = "\" { set end = end + 2  continue }
                quit:c=ch
                set end = end + 1
            }
            return:end>len "unterminated string at " _ pos
            set pos = end + 1
            continue
        }
        set matcher.Text = $extract(expr, pos, len)
        return:'matcher.Locate() "unexpected '" _ ch _ "' at " _ pos
        set tok = matcher.Group(0)
        if tok = "(" { set depth = depth + 1 }
        if tok = ")" { set depth = depth - 1  return:depth<0 "unbalanced ')' at " _ pos }
        set pos = pos + $length(tok)
    }
    return:depth'=0 "unbalanced '(': " _ depth _ " left open"
    return ""
}

ClassMethod Describe(when As %DynamicObject) As %String
{
    set out = ""
    set iter = when.%GetIterator()
    while iter.%GetNext(.key, .value) {
        set out = out _ $select(out = "": "", 1: ", ") _ key _ ": " _ value
    }
    return out
}

ClassMethod Fail(Output reason As %String, text As %String) As %Boolean
{
    set reason = text
    return 0
}

}
