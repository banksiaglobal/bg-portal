/// Component which can be rendered as a page. Pages are wrapped by every <package>.Layout
/// component found along their class name (Portal.WebApp.List -> Portal.Layout, Portal.WebApp.Layout).
Class Banksia.Bloom.Page Extends (%CSP.Page, Banksia.Bloom.Component)
{

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
	set className=..%ClassName(1)
	for i=1:1:$length(className,".") {
		set classPart=$piece(className,".",1,i)
		set layoutClassName=classPart_".Layout"
		if '##class(%Dictionary.CompiledClass).%ExistsId(layoutClassName) continue
		set layouts($increment(layouts))=layoutClassName
	}
	set layouts($increment(layouts))=..%ClassName(1)
	set componentStatus = ..WriteComponents(.layouts)
	if $$$ISERR(componentStatus) {
		write "</script>",!
		quit componentStatus
	}

	write "function bloomCreateApp(createApp) {",!
	write "const app = createApp("_$translate(layouts(1),".-%")_");",!
	for i=2:1:layouts {
      write "app.component('"_$translate(layouts(i),".-%")_"',"_$translate(layouts(i),".-%")_");",!
	}
	write "return app}"
	  
	write "</script>"

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
		set tCDef = ##class(%Dictionary.ClassDefinition).%OpenId(..%ClassName(1))
		if '$isobject(tCDef) {
			write "// Unable to find class definition ",..%ClassName(1),!
			quit
		}

		set xdc = tCDef.Properties.Count()
		for n = 1:1:xdc {
			#; get XDATA as stream
			set Prop=tCDef.Properties.GetAt(n)
			write Prop.Name_":"
			if Prop.Type="%String" write """"_..GetXssSafeString($zconvert($property($this,Prop.Name),"O","JS"))_""""
			if Prop.Type="%DynamicArray" write ..GetXssSafeString($method($property($this,Prop.Name),"%ToJSON"))
			if Prop.Type="%DynamicObject" write ..GetXssSafeString($method($property($this,Prop.Name),"%ToJSON"))
			if Prop.Type="%Boolean" write $select($property($this,Prop.Name):"true",1:"false")
			if Prop.Type="%Integer" write $select($property($this,Prop.Name)="":"null",1:..GetXssSafeString($property($this,Prop.Name)))
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
                else  write tLine,!
            }
        }
	}
	catch(ex) {
		set tSC = ex.AsStatus()
	}
	quit tSC
}

}
