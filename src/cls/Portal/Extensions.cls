/// Installed extensions: state, compatibility, last errors and id collisions,
/// with the switch to disable any of them. Reachable in safe mode (?safemode=1)
/// so a contribution that breaks the shell can still be turned off from here.
Class Portal.Extensions Extends Portal.Page
{

Parameter RESOURCE = "%Admin_Manage";

Parameter PAGEID = "system.extensions";

Parameter TITLE = "Extensions";

Property extensions As %DynamicArray;

Property collisions As %DynamicArray;

Property safeMode As %Boolean [ InitialExpression = {##class(Portal.Ext.Registry).SafeMode()} ];

Method %OnNew() As %Status
{
    set ..extensions = ..Describe()
    set ..collisions = ..Collisions()
    return $$$OK
}

ClassMethod Describe() As %DynamicArray
{
    set all = ##class(Portal.Ext.Registry).AllContributions()
    set iter = all.%GetIterator()
    while iter.%GetNext(.i, .ext) {
        set errors = []
        set hook = ""
        for {
            set hook = $order(^Portal.Ext("error", ext.class, hook), 1, text)
            quit:hook=""
            do errors.%Push({"hook": (hook), "text": (text)})
        }
        set ext.errors = errors
    }
    return all
}

ClassMethod Collisions() As %DynamicArray
{
    set out = []
    set hook = ""
    for {
        set hook = $order(^Portal.Ext("collision", hook))
        quit:hook=""
        set id = ""
        for {
            set id = $order(^Portal.Ext("collision", hook, id), 1, class)
            quit:id=""
            do out.%Push({"hook": (hook), "id": (id), "class": (class)})
        }
    }
    return out
}

ClassMethod SetEnabled(class As %String, enabled As %Boolean) As %String [ WebMethod ]
{
    return ..ActionResult(##class(Portal.Ext.Registry).SetEnabled(class, enabled))
}

ClassMethod ResetDiagnostics() As %String [ WebMethod ]
{
    kill ^Portal.Ext("error"), ^Portal.Ext("collision"), ^Portal.Ext("incompatible")
    return ..ActionResult($$$OK)
}

ClientMethod toggle(ext) [ Language = javascript ]
{
    await this.SetEnabled(ext.class, ext.enabled ? 0 : 1);
    location.reload();
}

ClientMethod clearDiagnostics() [ Language = javascript ]
{
    await this.ResetDiagnostics();
    location.reload();
}

XData Template [ MimeType = text/vue ]
{
<div>
  <div class="flex justify-between items-center mb-4">
    <div>
      <h1 class="text-2xl font-semibold">Extensions</h1>
      <p class="text-gray-600">Contributions discovered as subclasses of Portal.Ext.Contribution</p>
    </div>
    <div class="flex gap-2">
      <a v-if="safeMode" href="Portal.Extensions.cls" class="text-sm text-blue-600 self-center">Leave safe mode</a>
      <PButton label="Clear diagnostics" icon="pi pi-eraser" severity="secondary" size="small" outlined @click="clearDiagnostics" />
    </div>
  </div>

  <Card class="shadow-sm">
    <template #content>
      <DataTable :value="extensions" dataKey="class" size="small">
        <Column field="class" header="Class" :sortable="true" />
        <Column field="description" header="Description" />
        <Column field="order" header="Order" :sortable="true" :headerStyle="{ width: '1%' }" />
        <Column header="API" :headerStyle="{ width: '1%' }">
          <template #body="{ data }">
            <Tag :value="'v' + data.apiVersion" :severity="data.compatible ? 'secondary' : 'danger'" />
          </template>
        </Column>
        <Column header="Errors">
          <template #body="{ data }">
            <div v-for="e in data.errors" :key="e.hook" class="text-xs text-red-700"><b>{{ e.hook }}</b>: {{ e.text }}</div>
          </template>
        </Column>
        <Column header="Enabled" :headerStyle="{ width: '1%' }">
          <template #body="{ data }">
            <ToggleSwitch :modelValue="data.enabled" @update:modelValue="toggle(data)" />
          </template>
        </Column>
      </DataTable>
    </template>
  </Card>

  <Card v-if="collisions.length" class="shadow-sm mt-4">
    <template #title>Id collisions</template>
    <template #content>
      <p class="text-sm text-gray-600 mb-2">These items were skipped because an earlier contribution already used the same id.</p>
      <DataTable :value="collisions" size="small">
        <Column field="hook" header="Hook" />
        <Column field="id" header="Id" />
        <Column field="class" header="Skipped contribution" />
      </DataTable>
    </template>
  </Card>
</div>
}

}
