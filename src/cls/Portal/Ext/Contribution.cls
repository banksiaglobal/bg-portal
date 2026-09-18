/// Base class for portal extensions.
///
/// Subclass it, override the hooks you need, compile. Discovery is automatic
/// (see Portal.Ext.Registry). Every hook returns declarative data; the portal
/// only executes extension code through the class/method pairs an extension
/// declares itself in a column or an action.
///
/// Item shapes (all fields optional unless stated):
///   NavItems       {id*, label*, url*, icon, group, order, resource}
///   TopBarItems    {id*, label*, url*, icon, order, resource}
///   UserMenuItems  {id*, label*, url*, icon, order}
///   FooterItems    {id*, label*, url, order}
///   Columns        {key*, label*, order, sortable, class, method, resource}
///                  class/method: ClassMethod(row As %DynamicObject) As %String, computed server-side per row
///   Actions        {id*, label*, kind*, order, icon, severity, resource, confirm, visibleIf,
///                   url   (kind "navigate": {Field} placeholders are resolved from the row and URL-encoded; {Field|raw} is not encoded),
///                   class, method (kind "server": ClassMethod(row As %DynamicObject) As %Status)}
///                  visibleIf: {field, equals} hides the action on rows where row[field] != equals
///
/// `resource` on any item is enforced server-side: the item is not emitted unless
/// the current user holds USE on it, and server actions re-check it on invocation.
Class Portal.Ext.Contribution Extends %RegisteredObject [ Abstract ]
{

/// Extension API version this contribution was written against. The registry
/// refuses contributions targeting another version rather than half-loading them.
Parameter APIVERSION As INTEGER = 1;

/// Load order. Core contributions use 0-99; site extensions should stay at 100+.
/// Within one hook, items are ordered by their own `order`, then by load order.
Parameter ORDER As INTEGER = 100;

ClassMethod NavItems() As %DynamicArray
{
    return []
}

ClassMethod TopBarItems() As %DynamicArray
{
    return []
}

ClassMethod UserMenuItems() As %DynamicArray
{
    return []
}

ClassMethod FooterItems() As %DynamicArray
{
    return []
}

ClassMethod Columns(pageId As %String) As %DynamicArray
{
    return []
}

ClassMethod Actions(pageId As %String) As %DynamicArray
{
    return []
}

}
