/// Domain adapter over %Api.Admin.Endpoints.WebSession. This is the only place the portal
/// touches web (CSP) sessions; pages and extension actions call this, never
/// %Api.Admin.* or %CSP.Session directly. See Portal.Api.Service for the mechanics.
///
/// The endpoint only lists sessions and ends one by `id`; there is no GET or edit.
Class Portal.WebSession.Service Extends Portal.Api.Service
{

Parameter ENDPOINT = "%Api.Admin.Endpoints.WebSession";

Parameter IDPARAM = "id";

/// One row per session with the endpoint's list columns: ID, Username, Preserve,
/// Application, Timeout, LicenseId, SesProcessId, AllowEndSession.
ClassMethod List() As %DynamicArray
{
    new $namespace
    set $namespace = "%SYS"
    set list = ..Invoke(..#TYPELIST, "", {}, .sc)
    return:$$$ISERR(sc) []
    return list
}

/// Ends the session. Rows are keyed on ID, not Name.
ClassMethod EndSession(row As %DynamicObject) As %Status
{
    new $namespace
    set $namespace = "%SYS"
    do ..Invoke(..#TYPEDELETE, row.ID, {}, .sc)
    return sc
}

ClassMethod Delete(row As %DynamicObject) As %Status
{
    return ..EndSession(row)
}

}
