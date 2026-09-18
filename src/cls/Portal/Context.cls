/// Instance identity for the portal shell. Operators must always be able to see
/// which system they are acting on, so this is rendered on every page.
Class Portal.Context Extends %RegisteredObject
{

/// Display name of the system. Override per environment with
/// set ^Portal.Config("SYSTEM_NAME") = "..."; defaults to instance@host.
ClassMethod SystemName() As %String
{
    set name = $get(^Portal.Config("SYSTEM_NAME"))
    return:name'="" name
    return $piece($system, ":", 2) _ " @ " _ $piece($system, ":", 1)
}

/// One of LIVE, TEST, DEV, from ^Portal.Config("SYSTEM_TYPE"). Anything unrecognised
/// is treated as DEV so a misconfigured box never looks like production.
ClassMethod SystemType() As %String
{
    set type = $zconvert($get(^Portal.Config("SYSTEM_TYPE"), "DEV"), "U")
    return $select($listfind($listbuild("LIVE", "TEST", "DEV"), type): type, 1: "DEV")
}

ClassMethod UserName() As %String
{
    return $username
}

ClassMethod Version() As %String
{
    return $system.Version.GetNumber()
}

}
