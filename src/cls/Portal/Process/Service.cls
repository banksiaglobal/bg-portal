/// Domain adapter over %Api.Admin.Endpoints.Process. This is the only place the portal
/// touches process management; pages and extension actions call this, never
/// %Api.Admin.* or SYS.Process directly. See Portal.Api.Service for the mechanics.
///
/// Processes are not created or edited: the service lists, inspects, suspends, resumes,
/// terminates and broadcasts to them. The endpoint identifies a process by the `id`
/// query parameter (its PID), so rows are keyed on Pid rather than Name.
Class Portal.Process.Service Extends Portal.Api.Service
{

Parameter ENDPOINT = "%Api.Admin.Endpoints.Process";

Parameter IDPARAM = "id";

/// Request types understood only by the process endpoint.
Parameter TYPEBROADCAST = 10;

Parameter TYPERESUME = 11;

Parameter TYPESUSPEND = 12;

Parameter TYPETERMINATE = 13;

/// One row per process with the endpoint's list columns: Job, Pid, Username, Device,
/// Nspace, Routine, Commands, Globals, State, ClientName, EXEname, IPAddress,
/// CanBeExamined, CanBeSuspended, CanBeTerminated, CanReceiveBroadcast, PrvGblBlkCnt,
/// OSUserName, CPUTime, ParentPid, ElapsedTime.
ClassMethod List() As %DynamicArray
{
    new $namespace
    set $namespace = "%SYS"
    set list = ..Invoke(..#TYPELIST, "", {}, .sc)
    return:$$$ISERR(sc) []
    return list
}

/// Full detail for one process (including its Variables), or "" when it no longer
/// exists. The endpoint's JSON already carries Pid, so nothing is added.
ClassMethod Get(pid As %String) As %DynamicObject
{
    new $namespace
    set $namespace = "%SYS"
    set row = ..Invoke(..#TYPEGET, pid, {}, .sc)
    return:$$$ISERR(sc) ""
    return row
}

ClassMethod Suspend(row As %DynamicObject) As %Status
{
    new $namespace
    set $namespace = "%SYS"
    do ..Invoke(..#TYPESUSPEND, row.Pid, {}, .sc)
    return sc
}

ClassMethod Resume(row As %DynamicObject) As %Status
{
    new $namespace
    set $namespace = "%SYS"
    do ..Invoke(..#TYPERESUME, row.Pid, {}, .sc)
    return sc
}

ClassMethod Terminate(row As %DynamicObject) As %Status
{
    new $namespace
    set $namespace = "%SYS"
    do ..Invoke(..#TYPETERMINATE, row.Pid, {}, .sc)
    return sc
}

/// A process has no name; Delete is Terminate so generic callers (extension actions
/// wired to "Delete") behave sensibly.
ClassMethod Delete(row As %DynamicObject) As %Status
{
    return ..Terminate(row)
}

/// Sends `message` to every PID in `pids`. Processes that cannot receive a broadcast
/// (CanReceiveBroadcast = false) are silently skipped by IRIS.
ClassMethod Broadcast(pids As %DynamicArray, message As %String) As %Status
{
    new $namespace
    set $namespace = "%SYS"
    return:message="" $$$ERROR($$$GeneralError, "Message is required")
    return:pids.%Size()=0 $$$ERROR($$$GeneralError, "At least one process must be selected")
    do ..Invoke(..#TYPEBROADCAST, "", {"Message": (message), "PidList": (pids)}, .sc)
    return sc
}

}
