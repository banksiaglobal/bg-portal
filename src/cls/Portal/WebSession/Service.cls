/// Domain adapter over %Api.Admin.Endpoints.WebSession. This is the only place the portal
/// touches web (CSP) sessions; pages and extension actions call this, never
/// %Api.Admin.* or %CSP.Session directly. See Portal.Api.Service for the mechanics.
///
/// The endpoint only lists sessions and ends one by `id`; there is no GET or edit.
Class Portal.WebSession.Service Extends Portal.Api.Service
{

Parameter ENDPOINT = "%Api.Admin.Endpoints.WebSession";

Parameter IDPARAM = "id";

/// The session this request runs in; ending it would log the user out mid-action.
ClassMethod CurrentSessionId() As %String
{
    return $select($isobject($get(%session)): %session.SessionId, 1: "")
}

/// One row per session with the endpoint's list columns: ID, Username, Preserve,
/// Application, Timeout, LicenseId, SesProcessId, AllowEndSession, plus IsCurrent
/// for the caller's own session.
ClassMethod List() As %DynamicArray
{
    new $namespace
    set $namespace = "%SYS"
    set list = ..Invoke(..#TYPELIST, "", {}, .sc)
    return:$$$ISERR(sc) []
    set current = ..CurrentSessionId()
    set iter = list.%GetIterator()
    while iter.%GetNext(.i, .row) {
        do row.%Set("IsCurrent", row.ID = current, "boolean")
    }
    return list
}

/// Ends the session. Rows are keyed on ID, not Name. The current session is refused.
ClassMethod EndSession(row As %DynamicObject) As %Status
{
    return:row.ID=..CurrentSessionId() $$$ERROR($$$GeneralError, "Cannot end the current session (" _ row.ID _ ")")
    new $namespace
    set $namespace = "%SYS"
    do ..Invoke(..#TYPEDELETE, row.ID, {}, .sc)
    return sc
}

/// Ends every selected session; stops at the first failure and reports which one.
/// The current session is never ended, even if it made it into the selection.
ClassMethod EndSessions(rows As %DynamicArray) As %Status
{
    set current = ..CurrentSessionId()
    set ended = 0
    set iter = rows.%GetIterator()
    while iter.%GetNext(.i, .row) {
        continue:row.ID=current
        set sc = ..EndSession(row)
        return:$$$ISERR(sc) $$$ERROR($$$GeneralError, "Session " _ row.ID _ ": " _ $system.Status.GetErrorText(sc))
        set ended = ended + 1
    }
    return:((ended = 0) && rows.%Size()) $$$ERROR($$$GeneralError, "Cannot end the current session (" _ current _ ")")
    return $$$OK
}

ClassMethod Delete(row As %DynamicObject) As %Status
{
    return ..EndSession(row)
}

}
