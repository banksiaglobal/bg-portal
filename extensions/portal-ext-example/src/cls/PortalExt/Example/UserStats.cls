/// Dashboard widget: enabled / total user accounts, with a refresh that goes through
/// a WebMethod on this class (the component itself, not a page).
Class PortalExt.Example.UserStats Extends Banksia.Bloom.Component
{

Parameter PROPS = "ctx";

Property enabled As %Integer [ InitialExpression = 0 ];

Property total As %Integer [ InitialExpression = 0 ];

Property loading As %Boolean [ InitialExpression = 0 ];

Method %OnNew() As %Status
{
    set stats = ..Stats()
    set ..enabled = stats.enabled
    set ..total = stats.total
    return $$$OK
}

ClassMethod Stats() As %DynamicObject
{
    set enabled = 0
    set rows = ##class(Portal.User.Service).List()
    set iter = rows.%GetIterator()
    while iter.%GetNext(.i, .row) {
        set:row.Enabled enabled = enabled + 1
    }
    return {"enabled": (enabled), "total": (rows.%Size())}
}

ClassMethod Count() As %String [ WebMethod ]
{
    return ..Stats().%ToJSON()
}

ClientMethod refresh() [ Language = javascript ]
{
    this.loading = true;
    const stats = JSON.parse(await this.Count());
    this.enabled = stats.enabled;
    this.total = stats.total;
    this.loading = false;
}

XData Template [ MimeType = text/vue ]
{
<div class="flex items-center justify-between">
  <div>
    <div class="text-3xl font-semibold">{{ enabled }}<span class="text-base text-gray-500 font-normal"> / {{ total }}</span></div>
    <div class="text-sm text-gray-500">enabled user accounts</div>
  </div>
  <PButton icon="pi pi-refresh" text rounded severity="secondary" :loading="loading" aria-label="Refresh" @click="refresh" />
</div>
}

}
