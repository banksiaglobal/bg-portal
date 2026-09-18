/// Base page for the management portal. Every Portal.* page is wrapped by
/// Portal.Layout automatically (Banksia.Bloom.Page resolves <package>.Layout).
///
/// Access is governed by IRIS resources, not CIS menu credentials: a page declares
/// the resource it needs in RESOURCE and the check happens before any rendering.
Class Portal.Page Extends Banksia.Bloom.Page [ Abstract ]
{

/// IRIS resource the user must hold USE on to open the page. Empty means any authenticated user.
Parameter RESOURCE = "%Admin_Manage";

/// Identifier extensions use to target this page in Columns()/Actions().
Parameter PAGEID;

Parameter TITLE = "IRIS Portal";

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

/// Generic dispatcher for extension actions of kind "server". The registry re-applies
/// the resource check, and every invocation is written to ^Portal.Audit with the
/// contributing class so an action is always attributable to the extension that added it.
ClassMethod InvokeAction(actionId As %String, rowJson As %String) As %String [ WebMethod ]
{
    set action = ##class(Portal.Ext.Registry).FindAction(..#PAGEID, actionId)
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

}
