/// A Vue component. Properties become `data()`, ClientMethods and WebMethods become
/// `methods`, the Template XData becomes `template`. PROPS lists the Vue props the
/// component accepts (comma-separated), for components a page instantiates with
/// bindings such as `<component :is="..." :row="data" />`.
Class Banksia.Bloom.Component Extends %RegisteredObject
{

Parameter %JSONIGNOREINVALIDFIELD As BOOLEAN = 1;

/// Comma-separated Vue prop names, e.g. "row,col". Empty means no props.
Parameter PROPS;

XData Template
{
<child-outlet></child-outlet>
}

ClassMethod WriteComponentJs(componentName As %String = {$translate(..%ClassName(1),".-%")}, childName = "") As %Status [ ServerOnly = 1 ]
{

	set self=..%New()
	if '$isobject(self) {
		set status = $get(%objlasterror)
		if '$system.Status.IsError(status) {
			set status = ##class(%Exception.General).%New(
				"Unable to instantiate Bloom component "_..%ClassName(1)
			).AsStatus()
		}
		quit status
	}

	write componentName_"={",!
	if ..#PROPS '= "" {
		write "props: ["
		for i=1:1:$length(..#PROPS,",") write $select(i>1:",",1:""),"'"_$zstrip($piece(..#PROPS,",",i),"<>W")_"'"
		write "],",!
	}
    write "data() {",!
    write "    return {",!
	set status = self.WriteProps()
	quit:$$$ISERR(status) status
	write "}",!
	write "},",!
	write "template: `",!
	set status = self.WriteTemplate(childName)
	quit:$$$ISERR(status) status
	write "`,",!
	write "methods: {",!
	set status = self.WriteMethods()
	quit:$$$ISERR(status) status
	write "},",!
	write "}; ",!,!,!
	quit $$$OK
}

ClassMethod WriteTemplate(childName) As %Status [ ServerOnly = 1 ]
{
	set tSC = $$$OK

	try {
		do ..WriteXData(..%ClassName(1)_"||Template",childName)
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

Method GetXssSafeString(str) As %String [ ServerOnly = 1 ]
{
	return $replace($replace($replace(str,"<","\u003c"),">","\u003e"),"&","\u0026")
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
				while ('tStream.AtEnd) {
					write tStream.ReadLine(),!
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

ClassMethod UsesAwait(implementation As %Stream.Object) As %Boolean [ ServerOnly = 1 ]
{
	do implementation.Rewind()
	while 'implementation.AtEnd {
		return:implementation.ReadLine()["await" 1
	}
	return 0
}

ClassMethod WriteXData(id, childName) As %Status [ ServerOnly = 1 ]
{
    set tSC=$$$OK
	try {
		set xData = ##class(%Dictionary.CompiledXData).%OpenId(id)
        set tStream = xData.Data
        do tStream.Rewind()
        if (tStream.Size > 0) {
            while ('tStream.AtEnd) {
                set tLine = tStream.ReadLine()
				if tLine["<child-outlet" set tLine=$replace(tLine,"<child-outlet","<"_childName)
				if tLine["</child-outlet" set tLine=$replace(tLine,"</child-outlet","</"_childName)
                write tLine,!
            }
        }
	}
	catch(ex) {
		set tSC = ex.AsStatus()
	}
    quit tSC
}

}
