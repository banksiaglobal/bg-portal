Class Portal.Home Extends Portal.Page
{

Parameter RESOURCE;

Parameter PAGEID = "home";

Parameter TITLE = "Home";

Property systemName As %String [ InitialExpression = {##class(Portal.Context).SystemName()} ];

Property systemType As %String [ InitialExpression = {##class(Portal.Context).SystemType()} ];

Property version As %String [ InitialExpression = {##class(Portal.Context).Version()} ];

Property navItems As %DynamicArray;

Method %OnNew() As %Status
{
    set ..navItems = []
    set items = ##class(Portal.Ext.Registry).NavItems()
    set iter = items.%GetIterator()
    while iter.%GetNext(.i, .item) {
        continue:item.id="home"
        do ..navItems.%Push(item)
    }
    return $$$OK
}

XData Template [ MimeType = text/vue ]
{
<div>
  <h1 class="text-2xl font-semibold">{{ systemName }}</h1>
  <p class="text-gray-600 mt-1">InterSystems IRIS {{ version }} &#183; {{ systemType }}</p>

  <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 mt-8">
    <a v-for="item in navItems" :key="item.id" :href="item.url"
       class="block bg-white border border-gray-200 rounded-lg p-4 hover:border-blue-400 hover:shadow-sm transition">
      <div class="flex items-center gap-3">
        <i :class="[item.icon || 'pi pi-circle', 'text-xl text-blue-600']"></i>
        <div>
          <div class="font-medium">{{ item.label }}</div>
          <div v-if="item.group" class="text-xs text-gray-500">{{ item.group }}</div>
        </div>
      </div>
    </a>
  </div>
</div>
}

}
