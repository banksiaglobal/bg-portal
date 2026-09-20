/// Base for domain adapters over InterSystems' %Api.Admin endpoint classes.
///
/// An endpoint is driven in-process rather than over HTTP: it is instantiated with the
/// request type, fed its `name` query parameter and body, validated, and its Run()
/// result returned. IsRunningAsync is set so the endpoint never writes HTTP status or
/// headers into the portal page's own %response. Every call switches to %SYS, where
/// the Security.* classes the endpoints wrap live.
///
/// Subclasses set ENDPOINT (and SCHEMAMETHOD when the endpoint does not name its
/// request schema RequestBodySchema) and add the operations their domain needs;
/// Get / Delete / Enable / Disable are shared because every %Api.Admin endpoint
/// exposes them the same way.
Class Portal.Api.Service Extends %RegisteredObject [ Abstract ]
{

/// %Api.Admin.Endpoints.* class this service wraps.
Parameter ENDPOINT;

/// Method on the endpoint returning the request-body schema used to whitelist fields.
Parameter SCHEMAMETHOD = "RequestBodySchema";

/// Query parameter the endpoint identifies its object by. Security endpoints use
/// `name`; some (e.g. Process) use `id`.
Parameter IDPARAM = "name";

Parameter TYPELIST = 0;

Parameter TYPEGET = 1;

Parameter TYPEPUT = 2;

Parameter TYPEDELETE = 3;

Parameter TYPEPOST = 5;

/// Full detail for one object, or "" when it does not exist. The endpoint's JSON does
/// not carry the name, so it is added here.
ClassMethod Get(name As %String) As %DynamicObject
{
    new $namespace
    set $namespace = "%SYS"
    set row = ..Invoke(..#TYPEGET, name, {}, .sc)
    return:$$$ISERR(sc) ""
    set row.Name = name
    return row
}

ClassMethod Delete(row As %DynamicObject) As %Status
{
    new $namespace
    set $namespace = "%SYS"
    do ..Invoke(..#TYPEDELETE, row.Name, {}, .sc)
    return sc
}

ClassMethod Enable(row As %DynamicObject) As %Status
{
    return ..SetEnabled(row.Name, 1)
}

ClassMethod Disable(row As %DynamicObject) As %Status
{
    return ..SetEnabled(row.Name, 0)
}

ClassMethod SetEnabled(name As %String, enabled As %Boolean) As %Status
{
    new $namespace
    set $namespace = "%SYS"
    set body = {}
    do body.%Set("Enabled", enabled, "boolean")
    do ..Invoke(..#TYPEPUT, name, body, .sc)
    return sc
}

/// The endpoints' request validator rejects unknown fields, so only keys that appear in
/// the schema are forwarded. Booleans keep their JSON type; arrays are passed through.
ClassMethod SchemaSubset(obj As %DynamicObject) As %DynamicObject
{
    set body = {}
    set schema = $method($classmethod(..#ENDPOINT, "%New", ..#TYPEPUT), ..#SCHEMAMETHOD)
    set iter = schema.%GetIterator()
    while iter.%GetNext(.key, .default, .type) {
        continue:'obj.%IsDefined(key)
        do body.%Set(key, obj.%Get(key), $select(type = "boolean": "boolean", 1: ""))
    }
    return body
}

/// Runs one call against ENDPOINT. `type` is the %Api.Admin.Endpoint TYPE* value;
/// `name` becomes the IDPARAM query parameter. Validation and endpoint errors are
/// returned in `sc`.
ClassMethod Invoke(type As %Integer, name As %String, body As %DynamicObject, Output sc As %Status) As %DynamicObject
{
    return ..InvokeEndpoint(..#ENDPOINT, type, name, body, .sc, ..#IDPARAM)
}

/// Same as Invoke, against any endpoint class. Used when a service needs a lookup
/// from a neighbouring endpoint (e.g. role names for a user picker).
ClassMethod InvokeEndpoint(class As %String, type As %Integer, name As %String, body As %DynamicObject, Output sc As %Status, idParam As %String = "name") As %DynamicObject
{
    set sc = $$$OK
    set result = {}
    try {
        set endpoint = $classmethod(class, "%New", type)
        set endpoint.IsRunningAsync = 1
        do:name'="" endpoint.SaveOneQueryParam(idParam, name)
        do endpoint.ValidateQueryParams()
        set sc = endpoint.ValidateRequest(body)
        return:$$$ISERR(sc) result
        set result = endpoint.Run(.sc, body)
    } catch ex {
        set sc = ex.AsStatus()
    }
    return result
}

}
