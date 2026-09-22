/// Base page for the management portal. Every subclass is wrapped by Portal.Layout
/// (the LAYOUT parameter), whatever package it lives in, so extensions ship pages too.
///
/// Access is governed by IRIS resources, not CIS menu credentials: a page declares
/// the resource it needs in RESOURCE and the check happens before any rendering.
///
/// Extension points: a page's PAGEID names the slots extensions target
/// (page.<PAGEID>.columns / .actions / .bulk-actions / .fields on the list and edit
/// bases) and a template may declare widget slots anywhere with
///   <ext-slot name="after-form" ctx="obj" layout="grid|stack" class="mt-4" />
/// on one line. It is rewritten at emit time into the widget-card markup bound to
/// widgets["page.<PAGEID>.widgets.after-form"]; `ctx` is the expression handed to
/// each widget's `ctx` prop (default null). Declared slots are discovered by scanning
/// the class's XData blocks, so LoadWidgets() and Portal.Ext.Slots see them automatically.
Class Portal.Page Extends Banksia.Bloom.Page [ Abstract ]
{

/// The shell. Banksia.Bloom.Page emits these components around the page, outermost first.
Parameter LAYOUT = "Portal.Layout";

/// IRIS resource the user must hold USE on to open the page. Empty means any authenticated user.
Parameter RESOURCE = "%Admin_Manage";

/// Identifier extensions use to target this page's slots.
Parameter PAGEID;

Parameter TITLE = "IRIS Portal";

Property pageId As %String [ InitialExpression = {..#PAGEID} ];

Property user As %String [ InitialExpression = {$username} ];

/// Widgets per slot id, {"page.<id>.widgets.<name>": [...]}, computed when the page is emitted.
Property widgets As %DynamicObject [ Calculated ];

Method widgetsGet() As %DynamicObject
{
    return ..LoadWidgets()
}

ClassMethod OnPreHTTP() As %Boolean
{
    set %response.ContentType = "text/html"
    set %response.CharSet = "UTF-8"
    if (..#RESOURCE '= "") && '$system.Security.Check(..#RESOURCE, "USE") {
        set %response.ServerSideRedirect = "Portal.Forbidden.cls"
    }
    return 1
}

ClassMethod OnPage() As %Status
{
    return ##super(..#TITLE _ " - " _ ##class(Portal.Context).SystemName())
}

/// Widget slot ids this page renders, as a $list of "page.<PAGEID>.widgets.<name>".
/// Default: every <ext-slot> declared in the class's XData templates.
ClassMethod WidgetSlots() As %List
{
    set list = ""
    set def = ##class(%Dictionary.CompiledClass).%OpenId($classname())
    return:'$isobject(def) ""
    set matcher = ##class(%Regex.Matcher).%New("<ext-slot\s[^>]*?name=""([^""]+)""")
    for n = 1:1:def.XDatas.Count() {
        set stream = def.XDatas.GetAt(n).Data
        do stream.Rewind()
        while 'stream.AtEnd {
            set matcher.Text = stream.ReadLine()
            while matcher.Locate() {
                set slot = "page." _ ..#PAGEID _ ".widgets." _ matcher.Group(1)
                set:'$listfind(list, slot) list = list _ $listbuild(slot)
            }
        }
    }
    return list
}

/// Widgets for every slot of the page, valid components only, keyed by slot id.
ClassMethod LoadWidgets() As %DynamicObject
{
    set out = {}
    set slots = ..WidgetSlots()
    set ptr = 0
    while $listnext(slots, ptr, slot) {
        set list = []
        set widgets = ##class(Portal.Ext.Registry).Collect(slot)
        set iter = widgets.%GetIterator()
        while iter.%GetNext(.i, .w) {
            continue:'##class(Portal.Ext.Registry).ValidComponent(w.component, w.source, slot _ ":" _ w.id)
            do list.%Push(w)
        }
        do out.%Set(slot, list)
    }
    return out
}

/// Stylesheet/script links and inline <style>/<script> blocks contributed to shell.head,
/// filtered to items with no `page` (every page) or `page` = this page's PAGEID.
ClassMethod ExtraHead() As %String
{
    set out = ""
    set items = ##class(Portal.Ext.Registry).Collect("shell.head")
    set iter = items.%GetIterator()
    while iter.%GetNext(.i, .item) {
        continue:(item.page'="")&&(item.page'=..#PAGEID)
        set:item.url'="" out = out _ "<link rel=""stylesheet"" type=""text/css"" href=""" _ $zconvert(item.url, "O", "HTML") _ """>" _ $char(10)
        set:item.css'="" out = out _ "<style>" _ item.css _ "</style>" _ $char(10)
        set:item.src'="" out = out _ "<script src=""" _ $zconvert(item.src, "O", "HTML") _ """></script>" _ $char(10)
        set:item.js'="" out = out _ "<script>" _ item.js _ "</script>" _ $char(10)
    }
    return out
}

/// Components referenced by this page's extension columns and widgets. Subclasses that
/// declare their own component columns extend the list.
ClassMethod ExtraComponents() As %List
{
    set list = ""
    set columns = ##class(Portal.Ext.Registry).Collect("page." _ ..#PAGEID _ ".columns")
    set iter = columns.%GetIterator()
    while iter.%GetNext(.i, .col) {
        continue:col.component=""
        continue:'##class(Portal.Ext.Registry).ValidComponent(col.component, col.source, "page." _ ..#PAGEID _ ".columns:" _ col.key)
        set list = list _ $listbuild(col.component)
    }
    set widgets = ..LoadWidgets()
    set iter = widgets.%GetIterator()
    while iter.%GetNext(.slot, .items) {
        set inner = items.%GetIterator()
        while inner.%GetNext(.i, .w) {
            set list = list _ $listbuild(w.component)
        }
    }
    return list
}

/// Expands <ext-slot name="X" ctx="expr" layout="grid|stack" class="..." /> into the
/// widget-card markup. The tag must sit on one line.
ClassMethod TransformTemplateLine(line As %String) As %String
{
    return:line'["<ext-slot" line
    set matcher = ##class(%Regex.Matcher).%New("<ext-slot\s*([^>]*?)\s*/?>(</ext-slot>)?")
    set matcher.Text = line
    set out = ""
    set last = 1
    while matcher.Locate() {
        set out = out _ $extract(line, last, matcher.Start - 1) _ ..SlotMarkup(matcher.Group(1))
        set last = matcher.End
    }
    return out _ $extract(line, last, *)
}

ClassMethod SlotAttr(attrs As %String, name As %String, default As %String = "") As %String
{
    set m = ##class(%Regex.Matcher).%New("(?:^|\s)" _ name _ "=""([^""]*)""")
    set m.Text = attrs
    return $select(m.Locate(): m.Group(1), 1: default)
}

ClassMethod SlotMarkup(attrs As %String) As %String
{
    set name = ..SlotAttr(attrs, "name")
    set ctx = ..SlotAttr(attrs, "ctx", "null")
    set layout = ..SlotAttr(attrs, "layout", "grid")
    set class = ..SlotAttr(attrs, "class")
    set list = "slotWidgets('" _ name _ "', " _ ctx _ ")"
    set container = $select(layout = "stack": "flex flex-col gap-4", 1: "grid grid-cols-1 md:grid-cols-3 gap-4")
    set span = $select(layout = "stack": "", 1: " :class=""{ 'md:col-span-2': w.width === 2, 'md:col-span-3': w.width === 3 }""")
    return "<div v-if=""" _ list _ ".length"" class=""" _ container _ " " _ class _ """>" _
           "<Card v-for=""w in " _ list _ """ :key=""w.id"" class=""shadow-sm""" _ span _ ">" _
           "<template v-if=""w.title"" #title><span class=""text-base"">{{ w.title }}</span></template>" _
           "<template #content><component :is=""cmp(w.component)"" :ctx=""" _ ctx _ """ /></template>" _
           "</Card></div>"
}

/// Generic dispatcher for extension actions of kind "server". The registry re-applies
/// the resource check, and every invocation is written to ^Portal.Audit with the
/// contributing class so an action is always attributable to the extension that added it.
ClassMethod InvokeAction(actionId As %String, rowJson As %String) As %String [ WebMethod ]
{
    set action = ##class(Portal.Ext.Registry).FindItem("page." _ ..#PAGEID _ ".actions", actionId)
    return:'$isobject(action) ..ActionResult($$$ERROR($$$GeneralError, "Unknown action '" _ actionId _ "'"))
    return:action.kind'="server" ..ActionResult($$$ERROR($$$GeneralError, "Action '" _ actionId _ "' is not a server action"))

    set row = {}.%FromJSON(rowJson)
    set ^Portal.Audit($increment(^Portal.Audit)) = $listbuild($horolog, $username, ..#PAGEID, actionId, action.source, rowJson)
    set sc = $classmethod(action.class, action.method, row)
    return ..ActionResult(sc)
}

ClassMethod ActionResult(sc As %Status) As %String
{
    return:$$$ISOK(sc) {"ok": true}.%ToJSON()
    return {"ok": false, "error": ($system.Status.GetErrorText(sc))}.%ToJSON()
}

/// Vue component name of a Bloom component class: the emitter strips ".", "-" and "%".
ClientMethod cmp(cls) [ Language = javascript ]
{
    return (cls || '').replace(/[.%-]/g, '');
}

ClientMethod slotId(name) [ Language = javascript ]
{
    return 'page.' + this.pageId + '.widgets.' + name;
}

/// Widgets of a declared slot whose `when` holds for the given ctx.
ClientMethod slotWidgets(name, ctx) [ Language = javascript ]
{
    return (this.widgets[this.slotId(name)] || []).filter(w => this.passes(w, { ctx }));
}

/// True when the item has no `when`, or its `when` evaluates truthy. `user` and `page` are always in scope.
ClientMethod passes(item, scope) [ Language = javascript ]
{
    if (!item.when) return true;
    return this.evalWhen(item.when, Object.assign({ user: this.user, page: this.pageId }, scope));
}

/// Safe evaluator for `when` expressions: dot paths, string/number/boolean/null literals,
/// !, &&, ||, ==, !=, <, <=, >, >=, parentheses. No function calls, no assignment, no eval.
/// Any syntax error or runtime problem yields false.
ClientMethod evalWhen(expr, scope) [ Language = javascript ]
{
    const tokens = [];
    const re = /\s*(?:(\d+(?:\.\d+)?)|'((?:[^'\\]|\\.)*)'|"((?:[^"\\]|\\.)*)"|([A-Za-z_$][\w$]*(?:\.[A-Za-z_$][\w$]*)*)|(===|!==|==|!=|<=|>=|&&|\|\||[!<>()]))/y;
    let pos = 0;
    while (pos < expr.length) {
        re.lastIndex = pos;
        const m = re.exec(expr);
        if (!m || m[0].length === 0) {
            if (expr.slice(pos).trim() === '') break;
            return false;
        }
        pos = re.lastIndex;
        if (m[1] !== undefined) tokens.push({ t: 'lit', v: Number(m[1]) });
        else if (m[2] !== undefined) tokens.push({ t: 'lit', v: m[2].replace(/\\(.)/g, '$1') });
        else if (m[3] !== undefined) tokens.push({ t: 'lit', v: m[3].replace(/\\(.)/g, '$1') });
        else if (m[4] !== undefined) {
            const w = m[4];
            if (w === 'true') tokens.push({ t: 'lit', v: true });
            else if (w === 'false') tokens.push({ t: 'lit', v: false });
            else if (w === 'null') tokens.push({ t: 'lit', v: null });
            else tokens.push({ t: 'id', v: w });
        } else tokens.push({ t: 'op', v: m[5] });
    }
    let i = 0;
    const peek = () => tokens[i];
    const take = (v) => { const tok = tokens[i]; if (!tok || (v !== undefined && !(tok.t === 'op' && tok.v === v))) throw 0; i++; return tok; };
    const lookup = (path) => path.split('.').reduce((o, k) => (o === null || o === undefined) ? undefined : o[k], scope);
    const primary = () => {
        const tok = take();
        if (tok.t === 'lit') return tok.v;
        if (tok.t === 'id') return lookup(tok.v);
        if (tok.v === '(') { const v = or(); take(')'); return v; }
        if (tok.v === '!') return !primary();
        throw 0;
    };
    const rel = () => {
        let l = primary();
        for (;;) {
            const tok = peek();
            if (!tok || tok.t !== 'op' || !['<', '<=', '>', '>='].includes(tok.v)) return l;
            i++;
            const r = primary();
            l = tok.v === '<' ? l < r : tok.v === '<=' ? l <= r : tok.v === '>' ? l > r : l >= r;
        }
    };
    const eq = () => {
        let l = rel();
        for (;;) {
            const tok = peek();
            if (!tok || tok.t !== 'op' || !['==', '!=', '===', '!=='].includes(tok.v)) return l;
            i++;
            const r = rel();
            const same = (l === null || l === undefined || r === null || r === undefined) ? (l == r) : (l === r);
            l = (tok.v === '==' || tok.v === '===') ? same : !same;
        }
    };
    const and = () => {
        let l = eq();
        while (peek() && peek().t === 'op' && peek().v === '&&') { i++; const r = eq(); l = l && r; }
        return l;
    };
    const or = () => {
        let l = and();
        while (peek() && peek().t === 'op' && peek().v === '||') { i++; const r = and(); l = l || r; }
        return l;
    };
    try {
        if (tokens.length === 0) return false;
        const v = or();
        if (i !== tokens.length) return false;
        return !!v;
    } catch (e) {
        return false;
    }
}

}
