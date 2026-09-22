/// Installed extensions: manifest (name, id, version, publisher, ZPM module, required
/// resources), state, lifecycle and slot errors, id collisions, with the switch to
/// disable any of them and an Uninstall (retire) action, plus the extension points
/// reference: every slot with how many items are currently contributed to it and,
/// expanded, the item schema (keys, types, allowed values) with an example. Reachable
/// in safe mode (?safemode=1) so a contribution that breaks the shell can still be
/// turned off from here; "Clear cache" drops the registry's cached hook output.
Class Portal.Extensions Extends Portal.Page
{

Parameter RESOURCE = "%Admin_Manage";

Parameter PAGEID = "system.extensions";

Parameter TITLE = "Extensions";

Property extensions As %DynamicArray;

Property collisions As %DynamicArray;

Property slots As %DynamicArray;

Property overrides As %DynamicArray;

Property safeMode As %Boolean [ InitialExpression = {##class(Portal.Ext.Registry).SafeMode()} ];

Property pendingUninstall As %DynamicObject [ InitialExpression = {{}} ];

Property confirmVisible As %Boolean [ InitialExpression = 0 ];

Property error As %String;

Property expandedRows As %DynamicArray [ InitialExpression = {[]} ];

Property expandedExtensionRows As %DynamicArray [ InitialExpression = {[]} ];

Property cacheEnabled As %Boolean [ InitialExpression = {##class(Portal.Ext.Registry).CacheEnabled()} ];

Method %OnNew() As %Status
{
    // Slots first: collecting every slot refreshes the override and collision records.
    set ..slots = ##class(Portal.Ext.Slots).WithCounts()
    set ..overrides = ..Overrides()
    set ..collisions = ..Collisions()
    set ..extensions = ..Describe()
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
            do errors.%Push({"slot": (hook), "text": (text)})
        }
        set ext.errors = errors
        set warnings = []
        set hook = ""
        for {
            set hook = $order(^Portal.Ext("warning", ext.class, hook), 1, text)
            quit:hook=""
            do warnings.%Push({"slot": (hook), "text": (text)})
        }
        set ext.warnings = warnings
        set missing = []
        set iter2 = ext.requires.%GetIterator()
        while iter2.%GetNext(.j, .resource) {
            do:'$system.Security.Check(resource, "USE") missing.%Push(resource)
        }
        set ext.missing = missing
        set ext.overrides = ..OverridesBy(ext.class)
    }
    return all
}

/// [{slot, id, class, newId, hidden}] from ^Portal.Ext("override").
ClassMethod Overrides() As %DynamicArray
{
    set out = []
    set slot = ""
    for {
        set slot = $order(^Portal.Ext("override", slot))
        quit:slot=""
        set id = ""
        for {
            set id = $order(^Portal.Ext("override", slot, id), 1, by)
            quit:id=""
            set item = {"slot": (slot), "id": (id), "class": ($listget(by, 1)), "newId": ($listget(by, 2))}
            do item.%Set("hidden", $listget(by, 2) = "", "boolean")
            do out.%Push(item)
        }
    }
    return out
}

ClassMethod OverridesBy(class As %String) As %DynamicArray
{
    set out = []
    set all = ..Overrides()
    set iter = all.%GetIterator()
    while iter.%GetNext(.i, .o) {
        do:o.class=class out.%Push(o)
    }
    return out
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
            do out.%Push({"slot": (hook), "id": (id), "class": (class)})
        }
    }
    return out
}

ClassMethod SetEnabled(class As %String, enabled As %Boolean) As %String [ WebMethod ]
{
    return ..ActionResult(##class(Portal.Ext.Registry).SetEnabled(class, enabled))
}

ClassMethod Uninstall(class As %String) As %String [ WebMethod ]
{
    return ..ActionResult(##class(Portal.Ext.Registry).Uninstall(class))
}

ClassMethod Reinstall(class As %String) As %String [ WebMethod ]
{
    return ..ActionResult(##class(Portal.Ext.Registry).Reinstall(class))
}

/// Drops the recorded errors, warnings and collisions, and the cache with them so
/// every hook is re-run and re-validated on the next request.
ClassMethod ResetDiagnostics() As %String [ WebMethod ]
{
    kill ^Portal.Ext("error"), ^Portal.Ext("warning"), ^Portal.Ext("collision"), ^Portal.Ext("incompatible")
    do ##class(Portal.Ext.Registry).ClearCache()
    return ..ActionResult($$$OK)
}

ClassMethod ResetCache() As %String [ WebMethod ]
{
    do ##class(Portal.Ext.Registry).ClearCache()
    return ..ActionResult($$$OK)
}

ClientMethod toggle(ext) [ Language = javascript ]
{
    const result = JSON.parse(await this.SetEnabled(ext.class, ext.enabled ? 0 : 1));
    if (!result.ok) { this.error = result.error; return; }
    location.reload();
}

ClientMethod askUninstall(ext) [ Language = javascript ]
{
    this.pendingUninstall = ext;
    this.confirmVisible = true;
}

ClientMethod runUninstall() [ Language = javascript ]
{
    const result = JSON.parse(await this.Uninstall(this.pendingUninstall.class));
    if (!result.ok) { this.error = result.error; return; }
    location.reload();
}

ClientMethod runReinstall(ext) [ Language = javascript ]
{
    const result = JSON.parse(await this.Reinstall(ext.class));
    if (!result.ok) { this.error = result.error; return; }
    location.reload();
}

ClientMethod lacks(ext, resource) [ Language = javascript ]
{
    return ext.missing.includes(resource);
}

ClientMethod clearDiagnostics() [ Language = javascript ]
{
    await this.ResetDiagnostics();
    location.reload();
}

ClientMethod clearCache() [ Language = javascript ]
{
    await this.ResetCache();
    location.reload();
}

ClientMethod exampleOf(slot) [ Language = javascript ]
{
    return slot.schema ? JSON.stringify(slot.schema.example) : '';
}

ClientMethod enumOf(spec) [ Language = javascript ]
{
    return (spec.enum || []).join(' | ');
}

XData Template [ MimeType = text/vue ]
{
<div>
  <div class="flex justify-between items-center mb-4">
    <div>
      <h1 class="text-2xl font-semibold">Extensions</h1>
      <p class="text-sm text-gray-600">Contributions discovered as subclasses of Portal.Ext.Contribution</p>
    </div>
    <div class="flex gap-2">
      <a v-if="safeMode" href="Portal.Extensions.cls" class="text-sm text-blue-600 self-center">Leave safe mode</a>
      <PButton label="Clear diagnostics" icon="pi pi-eraser" severity="secondary" size="small" outlined @click="clearDiagnostics" />
      <PButton label="Clear cache" icon="pi pi-refresh" severity="secondary" size="small" outlined @click="clearCache"
               v-tooltip.bottom="cacheEnabled ? 'Drop the cached Contribute() output; hooks run again on the next request' : 'The contribution cache is off (?nocache=1 or ^Portal.Config(&quot;EXT_CACHE&quot;) = 0)'" />
    </div>
  </div>

  <div v-if="error" class="mb-4 flex items-start gap-2 rounded border border-red-300 bg-red-50 px-3 py-2 text-sm text-red-800">
    <i class="pi pi-exclamation-triangle mt-0.5"></i><span>{{ error }}</span>
  </div>

  <Card class="shadow-sm">
    <template #content>
      <DataTable :value="extensions" dataKey="class" size="small" class="text-sm" v-model:expandedRows="expandedExtensionRows">
        <Column expander :headerStyle="{ width: '1%' }" />
        <Column header="Extension" :sortable="true" sortField="name">
          <template #body="{ data }">
            <div class="text-sm font-medium flex items-center gap-2">
              {{ data.name }}
              <Tag v-if="data.version" :value="'v' + data.version" severity="secondary" />
              <Tag v-if="data.retired" value="retired" severity="warn" />
              <Tag v-if="!data.compatible" :value="'API v' + data.apiVersion" severity="danger" v-tooltip.top="'Written against another extension API version; not loaded'" />
            </div>
            <div class="text-xs text-gray-500 font-mono">{{ data.id }}</div>
            <div class="text-xs text-gray-500">{{ data.class }} &#183; order {{ data.order }}</div>
          </template>
        </Column>
        <Column header="Publisher">
          <template #body="{ data }">
            <a v-if="data.homepage" :href="data.homepage" target="_blank" rel="noopener" class="text-sm text-blue-600 hover:underline">{{ data.publisher || data.homepage }}</a>
            <span v-else class="text-sm">{{ data.publisher }}</span>
          </template>
        </Column>
        <Column header="Module">
          <template #body="{ data }">
            <div v-if="data.module" class="text-sm"><span class="font-mono text-xs">{{ data.module.name }}</span> <Tag :value="data.module.version" severity="secondary" /></div>
            <span v-else class="text-xs text-gray-400">not from a ZPM module</span>
          </template>
        </Column>
        <Column header="Requires">
          <template #body="{ data }">
            <div class="flex flex-wrap gap-1">
              <Tag v-for="r in data.requires" :key="r" :value="r" :severity="lacks(data, r) ? 'danger' : 'secondary'"
                   v-tooltip.top="lacks(data, r) ? 'You do not hold USE on this resource' : ''" />
            </div>
          </template>
        </Column>
        <Column header="Installed" :sortable="true" sortField="installedAt" :headerStyle="{ whiteSpace: 'nowrap' }">
          <template #body="{ data }"><span class="text-xs whitespace-nowrap">{{ data.installedAt }}</span></template>
        </Column>
        <Column header="Errors">
          <template #body="{ data }">
            <div v-for="e in data.errors" :key="e.slot" class="text-xs text-red-700"><b>{{ e.slot }}</b>: {{ e.text }}</div>
            <div v-for="w in data.warnings" :key="'w' + w.slot" class="text-xs text-amber-700"><i class="pi pi-exclamation-triangle text-xs"></i> <b>{{ w.slot }}</b>: {{ w.text }}</div>
          </template>
        </Column>
        <Column header="Enabled" :headerStyle="{ width: '1%' }">
          <template #body="{ data }">
            <ToggleSwitch v-if="!data.retired" :modelValue="data.enabled" @update:modelValue="toggle(data)" />
          </template>
        </Column>
        <Column header="" :headerStyle="{ width: '1%' }">
          <template #body="{ data }">
            <PButton v-if="data.retired" icon="pi pi-replay" label="Reinstall" size="small" severity="secondary" outlined @click="runReinstall(data)" />
            <PButton v-else icon="pi pi-trash" text rounded size="small" severity="danger" v-tooltip.top="'Uninstall (retire)'" aria-label="Uninstall" @click="askUninstall(data)" />
          </template>
        </Column>
        <template #expansion="{ data }">
          <div v-if="data.description || data.overrides.length" class="px-4 py-2 bg-gray-50 rounded">
            <div v-if="data.description" class="text-sm text-gray-700 whitespace-pre-line">{{ data.description }}</div>
            <div v-if="data.overrides.length" class="text-xs text-amber-700 mt-1">
              <i class="pi pi-exclamation-circle"></i>
              Overrides core: <span v-for="(o, i) in data.overrides" :key="o.slot + o.id">{{ i ? ', ' : '' }}{{ o.hidden ? 'hides' : 'replaces' }} <span class="font-mono">{{ o.id }}</span> in <span class="font-mono">{{ o.slot }}</span></span>
            </div>
          </div>
        </template>
      </DataTable>
    </template>
  </Card>

  <ConfirmDialog v-model:visible="confirmVisible"
                 :title="'Uninstall ' + (pendingUninstall.name || '')"
                 :message="'This runs the OnUninstall hook of the extension, drops its state and stops loading it. The class ' + (pendingUninstall.class || '') + ' stays on the instance; remove the code with zpm uninstall.'"
                 confirmLabel="Uninstall"
                 @confirm="runUninstall" />

  <Card class="shadow-sm mt-4">
    <template #title>Extension points</template>
    <template #content>
      <p class="text-sm text-gray-600 mb-2">Every slot a contribution can fill, generated from the shell and the installed pages. Counts are the items visible to you. Expand a row for the item keys and an example; the same reference as text: <span class="font-mono text-xs">##class(Portal.Ext.Slots).Markdown()</span>.</p>
      <DataTable :value="slots" size="small" class="text-sm" dataKey="id" :paginator="slots.length > 50" :rows="50" v-model:expandedRows="expandedRows">
        <Column expander :headerStyle="{ width: '1%' }" />
        <Column field="id" header="Slot" sortable>
          <template #body="{ data }"><span class="font-mono text-xs">{{ data.id }}</span></template>
        </Column>
        <Column field="kind" header="Kind" sortable :headerStyle="{ width: '1%' }">
          <template #body="{ data }"><Tag :value="data.kind" severity="secondary" /></template>
        </Column>
        <Column field="page" header="Page" sortable>
          <template #body="{ data }"><span class="text-sm">{{ data.page }}</span></template>
        </Column>
        <Column field="description" header="Description">
          <template #body="{ data }"><span class="text-sm">{{ data.description }}</span></template>
        </Column>
        <Column field="count" header="Items" sortable :headerStyle="{ width: '1%' }">
          <template #body="{ data }"><span class="text-sm" :class="data.count ? 'font-medium' : 'text-gray-400'">{{ data.count }}</span></template>
        </Column>
        <template #expansion="{ data }">
          <div v-if="data.schema" class="px-4 py-2 bg-gray-50 rounded">
            <table class="text-xs w-full">
              <thead><tr class="text-left text-gray-500"><th class="pr-4 py-1">Key</th><th class="pr-4">Type</th><th class="pr-4">Required</th><th class="pr-4">Values</th><th>Notes</th></tr></thead>
              <tbody>
                <tr v-for="(spec, key) in data.schema.keys" :key="key" class="border-t border-gray-200 align-top">
                  <td class="pr-4 py-1 font-mono">{{ key }}</td>
                  <td class="pr-4 py-1">{{ spec.type }}</td>
                  <td class="pr-4 py-1"><Tag v-if="spec.required" value="required" severity="info" /></td>
                  <td class="pr-4 py-1 font-mono">{{ enumOf(spec) }}</td>
                  <td class="py-1 text-gray-600">{{ spec.doc }}</td>
                </tr>
              </tbody>
            </table>
            <div class="mt-2 text-xs"><span class="text-gray-500">Example:</span> <code class="font-mono">{{ exampleOf(data) }}</code></div>
            <div class="mt-1 text-xs text-gray-500">Every item may also carry <span class="font-mono">replaces, hide, when, resource, order</span>.</div>
          </div>
        </template>
      </DataTable>
    </template>
  </Card>

  <Card v-if="overrides.length" class="shadow-sm mt-4">
    <template #title>Overrides</template>
    <template #content>
      <p class="text-sm text-gray-600 mb-2">Core or earlier items deliberately replaced or hidden by an extension (replaces / hide).</p>
      <DataTable :value="overrides" size="small" class="text-sm">
        <Column field="slot" header="Slot"><template #body="{ data }"><span class="font-mono text-xs">{{ data.slot }}</span></template></Column>
        <Column field="id" header="Target id"><template #body="{ data }"><span class="font-mono text-xs">{{ data.id }}</span></template></Column>
        <Column header="Outcome">
          <template #body="{ data }">
            <span v-if="data.hidden" class="text-sm">hidden by <span class="font-mono text-xs">{{ data.class }}</span></span>
            <span v-else class="text-sm">replaced by <span class="font-mono text-xs">{{ data.class }}</span> as <span class="font-mono text-xs">{{ data.newId }}</span></span>
          </template>
        </Column>
      </DataTable>
    </template>
  </Card>

  <Card v-if="collisions.length" class="shadow-sm mt-4">
    <template #title>Id collisions</template>
    <template #content>
      <p class="text-sm text-gray-600 mb-2">These items were skipped because an earlier contribution already used the same id in that slot, or already replaced that target.</p>
      <DataTable :value="collisions" size="small" class="text-sm">
        <Column field="slot" header="Slot">
          <template #body="{ data }"><span class="font-mono text-xs">{{ data.slot }}</span></template>
        </Column>
        <Column field="id" header="Id">
          <template #body="{ data }"><span class="font-mono text-xs">{{ data.id }}</span></template>
        </Column>
        <Column field="class" header="Skipped contribution">
          <template #body="{ data }"><span class="text-sm">{{ data.class }}</span></template>
        </Column>
      </DataTable>
    </template>
  </Card>
</div>
}

}
