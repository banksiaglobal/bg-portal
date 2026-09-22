/// Component which can be rendered as a page. The shell around the page is the chain of
/// layout components named in LAYOUT (outermost first); when LAYOUT is empty the chain is
/// every <package>.Layout component found along the class name
/// (Portal.WebApp.List -> Portal.Layout, Portal.WebApp.Layout), the historic behaviour.
Class Banksia.Bloom.Page Extends (%CSP.Page, Banksia.Bloom.Component)
{

/// Comma-separated layout component classes wrapping the page, outermost first
/// ("Portal.Layout"). Empty: derive them from the class name (<pkg>.Layout for every
/// package prefix), which ties the page to its package; a base page sets it so that
/// subclasses can live in any package.
Parameter LAYOUT;

Parameter CHARSET = "UTF-8";

Parameter CONTENTTYPE = "text/html";

XData Template
{
<div></div>
}

ClassMethod OnPreHTTP() As %Boolean
{
  set:%response.ContentType="" %response.ContentType = "text/html"
  set %response.CharSet = "UTF-8"
  return 1
}

ClassMethod OnPage(title = "BG") As %Status [ ProcedureBlock = 1, ServerOnly = 1 ]
{
	&html<
<html>
<head>
<meta charset="UTF-8">
<title>#(title)#</title>
<link href="ui/assets/index.css" rel="stylesheet" type="text/css">
>
	write "<script language=""javaScript"">"
	do ..LayoutChain(.layouts)
	set layouts($increment(layouts))=..%ClassName(1)
	set componentStatus = ..WriteComponents(.layouts)
	if $$$ISERR(componentStatus) {
		write "</script>",!
		quit componentStatus
	}

	// Extra components the page asks for (extension cells, widgets): emitted once each,
	// after the layout chain, and registered globally so templates can use them by name.
	set list = ..ExtraComponents()
	set ptr = 0
	set extras = 0
	while $listnext(list, ptr, class) {
		continue:class=""
		continue:$data(emitted(class))
		set isLayout = 0
		for i=1:1:layouts set:layouts(i)=class isLayout = 1
		continue:isLayout
		continue:'##class(%Dictionary.CompiledClass).%ExistsId(class)
		set emitted(class) = ""
		set componentStatus = $classmethod(class, "WriteComponentJs", $translate(class, ".-%"), "")
		if $$$ISERR(componentStatus) {
			write "</script>",!
			quit
		}
		set extras($increment(extras)) = class
	}
	quit:$$$ISERR(componentStatus) componentStatus

	write "function bloomCreateApp(createApp) {",!
	write "const app = createApp("_$translate(layouts(1),".-%")_");",!
	for i=2:1:layouts {
      write "app.component('"_$translate(layouts(i),".-%")_"',"_$translate(layouts(i),".-%")_");",!
	}
	for i=1:1:extras {
      write "app.component('"_$translate(extras(i),".-%")_"',"_$translate(extras(i),".-%")_");",!
	}
	write "return app}"

	write "</script>"
	write ..ExtraHead()

 &html<
</head>
<body id="body"> 
    <div id="appDiv">
    </div>
    <script type="module" crossorigin src="ui/assets/index.js"></script>
</body>
</html>
    
>
	quit $$$OK
}

/// The layout components wrapping this page, outermost first, into layouts(n): LAYOUT
/// when set (classes that do not exist are skipped), else the <pkg>.Layout walk.
ClassMethod LayoutChain(ByRef layouts) [ ServerOnly = 1 ]
{
	set layouts = $get(layouts, 0)
	if ..#LAYOUT '= "" {
		for i=1:1:$length(..#LAYOUT, ",") {
			set layoutClassName = $zstrip($piece(..#LAYOUT, ",", i), "<>W")
			continue:layoutClassName=""
			continue:'##class(%Dictionary.CompiledClass).%ExistsId(layoutClassName)
			set layouts($increment(layouts)) = layoutClassName
		}
		return
	}
	set className = ..%ClassName(1)
	for i=1:1:$length(className, ".") {
		set layoutClassName = $piece(className, ".", 1, i) _ ".Layout"
		continue:'##class(%Dictionary.CompiledClass).%ExistsId(layoutClassName)
		set layouts($increment(layouts)) = layoutClassName
	}
}

/// Additional Banksia.Bloom.Component classes to emit with this page, as a $list of
/// class names. Override to let the page pull in components it references by name.
ClassMethod ExtraComponents() As %List
{
	return ""
}

/// Extra markup written into <head> just before it closes (stylesheet links, inline
/// <style> blocks). Override to contribute markup that isn't a Vue component;
/// ExtraComponents() is for those.
ClassMethod ExtraHead() As %String
{
	return ""
}

ClassMethod WriteComponents(ByRef layouts) As %Status [ ServerOnly = 1 ]
{
	for index=1:1:$get(layouts) {
		set status = $classmethod(
			layouts(index),
			"WriteComponentJs",
			$translate(layouts(index), ".-%"),
			$translate($get(layouts(index+1)), ".-%")
		)
		quit:$$$ISERR(status)
	}
	quit $get(status, $$$OK)
}

Method CreateAppComponent() As %Status [ ServerOnly = 1 ]
{
	write "App={",!
    write "data() {",!
    write "    return {",!
	do ..WriteProps()
	write "}",!
	write "},",!
	write "template: `",!
	do ..WriteTemplate()
	write "`,",!
	write "methods: {",!
	do ..WriteMethods()
	write "},",!
	write "}"
}

ClassMethod WriteTemplate() As %Status [ ServerOnly = 1 ]
{
	set tSC = $$$OK

	try {
		do ..WriteXData(..%ClassName(1)_"||Template")
	}
	catch(ex) {
		set tSC = ex.AsStatus()
	}

	quit tSC
}

Method WriteProps() As %Status [ ServerOnly = 1 ]
{
	set tSC = $$$OK

	try {
		// Compiled definition so properties inherited from an abstract base (Portal.ListPage, ...) are emitted too.
		set tCDef = ##class(%Dictionary.CompiledClass).%OpenId(..%ClassName(1))
		if '$isobject(tCDef) {
			write "// Unable to find class definition ",..%ClassName(1),!
			quit
		}

		set xdc = tCDef.Properties.Count()
		for n = 1:1:xdc {
			set Prop=tCDef.Properties.GetAt(n)
			continue:$extract(Prop.Name)="%"
			set type = $piece(Prop.Type, ".", *)
			continue:'$listfind($listbuild("String","DynamicArray","DynamicObject","Boolean","Integer"),type)
			write Prop.Name_":"
			if type="String" write """"_..GetXssSafeString($zconvert($property($this,Prop.Name),"O","JS"))_""""
			if type="DynamicArray" write ..GetXssSafeString($method($property($this,Prop.Name),"%ToJSON"))
			if type="DynamicObject" write ..GetXssSafeString($method($property($this,Prop.Name),"%ToJSON"))
			if type="Boolean" write $select($property($this,Prop.Name):"true",1:"false")
			if type="Integer" write $select($property($this,Prop.Name)="":"null",1:..GetXssSafeString($property($this,Prop.Name)))
			write ","
		}
	}
	catch(ex) {
		set tSC = ex.AsStatus()
	}

	quit tSC
}

Method WriteMethods() As %Status [ ServerOnly = 1 ]
{
	set tSC = $$$OK

	try {
		set tCDef = ##class(%Dictionary.CompiledClass).%OpenId(..%ClassName(1))
		if '$isobject(tCDef) {
			write "// Unable to find class definition ",..%ClassName(1),!
			quit
		}

		set xdc = tCDef.Methods.Count()
		for n = 1:1:xdc {
			#; get XDATA as stream
			set Method=tCDef.Methods.GetAt(n)
			if ('Method.WebMethod) && ('Method.ZenMethod) && ('Method.ClientMethod) continue
			if Method.Language="javascript" {
				// Only methods that await are emitted async, so helpers stay usable in template expressions.
				write !,Method.Name_": "_$select(..UsesAwait(Method.Implementation):"async ",1:"")_"function("
				for i=1:1:$length(Method.FormalSpec,",") {
					set Param=$piece(Method.FormalSpec,",",i)
					write $piece(Param,":",1)
					if i<$length(Method.FormalSpec,",") write ","
				}
				write ") {"
				set tStream = Method.Implementation
				do tStream.Rewind()
				if (tStream.Size > 0) {
					while ('tStream.AtEnd) {
						set tLine = tStream.ReadLine()
						write tLine,!
					}
				}
			} else {
				write Method.Name_": async function() {"
				write "return serverCall("""_$$$cspEncodeBroker(%session.Key,$listbuild($classname()_"."_Method.Name))_""",['',...arguments]);"
			}
			write "},"
		}
	}
	catch(ex) {
		set tSC = ex.AsStatus()
	}

	quit tSC
}

/// Hook for subclasses to rewrite template lines while they are emitted (Portal.Page
/// expands <ext-slot> here). Default: unchanged.
ClassMethod TransformTemplateLine(line As %String) As %String
{
	return line
}

ClassMethod WriteXData(id) As %Status [ ServerOnly = 1 ]
{
    set tSC=$$$OK
	try {
		set xData = ##class(%Dictionary.CompiledXData).%OpenId(id)
        set tStream = xData.Data
        do tStream.Rewind()
        if (tStream.Size > 0) {
            while ('tStream.AtEnd) {
                set tLine = tStream.ReadLine()
				if tLine["@include " do ..WriteXData(..%ClassName(1)_"||"_$piece(tLine,"@include ",2))
                else  write ..TransformTemplateLine(tLine),!
            }
        }
	}
	catch(ex) {
		set tSC = ex.AsStatus()
	}
	quit tSC
}

}
