/// Process list. Columns and row actions are the union of the core set declared here
/// and whatever Portal.Ext.Registry contributes for page id "process.list".
/// Rows can be multi-selected for a broadcast message; only processes that report
/// CanReceiveBroadcast are selectable.
Class Portal.Process.List Extends Portal.Page
{

Parameter RESOURCE = "%Admin_Operate";

Parameter PAGEID = "process.list";

Parameter TITLE = "Processes";

Property rows As %DynamicArray;

Property columns As %DynamicArray;

Property actions As %DynamicArray;

Property filters As %DynamicObject [ InitialExpression = {{"global": {"value": ""}}} ];

Property pending As %DynamicObject [ InitialExpression = {{}} ];

Property confirmVisible As %Boolean [ InitialExpression = 0 ];

Property selected As %DynamicArray [ InitialExpression = {[]} ];

Property broadcastVisible As %Boolean [ InitialExpression = 0 ];

Property broadcastMessage As %String;

Property sending As %Boolean [ InitialExpression = 0 ];

Property error As %String;

Property notice As %String;

Method %OnNew() As %Status
{
    set ..columns = ..BuildColumns()
    set ..actions = ##class(Portal.Ext.Registry).Actions(..#PAGEID)
    set ..rows = ..BuildRows(..columns)
    return $$$OK
}

ClassMethod CoreColumns() As %DynamicArray
{
    return [
        {"key": "Pid", "label": "PID", "sortable": true, "order": 10},
        {"key": "Job", "label": "Job", "sortable": true, "order": 20},
        {"key": "Username", "label": "User", "sortable": true, "order": 30},
        {"key": "Nspace", "label": "Namespace", "sortable": true, "order": 40},
        {"key": "Routine", "label": "Routine", "sortable": true, "order": 50},
        {"key": "State", "label": "State", "sortable": true, "order": 60},
        {"key": "Device", "label": "Device", "order": 70},
        {"key": "Commands", "label": "Commands", "sortable": true, "order": 80},
        {"key": "Globals", "label": "Globals", "sortable": true, "order": 90},
        {"key": "CPUTime", "label": "CPU time", "sortable": true, "order": 100},
        {"key": "ElapsedTime", "label": "Elapsed", "sortable": true, "order": 110},
        {"key": "ClientName", "label": "Client", "sortable": true, "order": 120},
        {"key": "IPAddress", "label": "IP address", "sortable": true, "order": 130},
        {"key": "OSUserName", "label": "OS user", "sortable": true, "order": 140}
    ]
}

ClassMethod BuildColumns() As %DynamicArray
{
    set columns = ..CoreColumns()
    set extra = ##class(Portal.Ext.Registry).Columns(..#PAGEID)
    set iter = extra.%GetIterator()
    while iter.%GetNext(.i, .col) {
        do columns.%Push(col)
    }
    return ##class(Portal.Ext.Registry).Sort(columns)
}

/// Extension columns are computed on the server so the client only ever sees plain fields.
/// A failing column renders as a marker on that row instead of breaking the page.
ClassMethod BuildRows(columns As %DynamicArray) As %DynamicArray
{
    set rows = ##class(Portal.Process.Service).List()
    set rowIter = rows.%GetIterator()
    while rowIter.%GetNext(.r, .row) {
        set colIter = columns.%GetIterator()
        while colIter.%GetNext(.c, .col) {
            continue:col.class=""
            try {
                do row.%Set(col.key, $classmethod(col.class, col.method, row))
            } catch ex {
                do row.%Set(col.key, "#ERR")
                set ^Portal.Ext("error", col.source, "Columns:" _ col.key) = ex.DisplayString()
            }
        }
    }
    return rows
}

ClassMethod Reload() As %String [ WebMethod ]
{
    return ..BuildRows(..BuildColumns()).%ToJSON()
}

ClassMethod Broadcast(pidsJson As %String, message As %String) As %String [ WebMethod ]
{
    set sc = ##class(Portal.Process.Service).Broadcast([].%FromJSON(pidsJson), message)
    return ..ActionResult(sc)
}

ClientMethod openRow(event) [ Language = javascript ]
{
    location.href = "Portal.Process.Detail.cls?id=" + encodeURIComponent(event.data.Pid);
}

ClientMethod refresh() [ Language = javascript ]
{
    this.error = '';
    this.rows = JSON.parse(await this.Reload());
    const live = new Set(this.rows.map(r => r.Pid));
    this.selected = this.selected.filter(r => live.has(r.Pid));
}

ClientMethod visibleActions(row) [ Language = javascript ]
{
    return this.actions.filter(a => !a.visibleIf || row[a.visibleIf.field] === a.visibleIf.equals);
}

ClientMethod resolveUrl(url, row) [ Language = javascript ]
{
    return url.replace(/\{(\w+)(\|raw)?\}/g, (m, key, raw) => raw ? (row[key] ?? '') : encodeURIComponent(row[key] ?? ''));
}

ClientMethod runAction(action, row) [ Language = javascript ]
{
    if (action.kind === 'navigate') {
        location.href = this.resolveUrl(action.url, row);
        return;
    }
    this.pending = { action, row };
    if (action.confirm) {
        this.confirmVisible = true;
        return;
    }
    await this.executePending();
}

ClientMethod executePending() [ Language = javascript ]
{
    const { action, row } = this.pending;
    this.error = '';
    this.notice = '';
    const result = JSON.parse(await this.InvokeAction(action.id, JSON.stringify(row)));
    if (!result.ok) {
        this.error = result.error;
        return;
    }
    await this.refresh();
}

ClientMethod rowSelectable(row) [ Language = javascript ]
{
    return !!row.CanReceiveBroadcast;
}

/// Checkbox selection cannot be restricted per row in the table, so a process that
/// cannot receive a broadcast is dropped from the selection as soon as it is ticked.
ClientMethod onRowSelect(event) [ Language = javascript ]
{
    if (!this.rowSelectable(event.data)) {
        this.selected = this.selected.filter(r => r.Pid !== event.data.Pid);
    }
}

ClientMethod onSelectAll() [ Language = javascript ]
{
    this.selected = this.rows.filter(r => this.rowSelectable(r));
}

ClientMethod openBroadcast() [ Language = javascript ]
{
    this.broadcastMessage = '';
    this.broadcastVisible = true;
}

ClientMethod sendBroadcast() [ Language = javascript ]
{
    this.error = '';
    this.notice = '';
    this.sending = true;
    const pids = this.selected.map(r => r.Pid);
    const result = JSON.parse(await this.Broadcast(JSON.stringify(pids), this.broadcastMessage));
    this.sending = false;
    if (!result.ok) {
        this.error = result.error;
        return;
    }
    this.broadcastVisible = false;
    this.notice = 'Message sent to ' + pids.length + ' process' + (pids.length === 1 ? '' : 'es') + '.';
    this.selected = [];
}

XData Template [ MimeType = text/vue ]
{
<div>
  <div class="flex justify-between items-center mb-4">
    <div>
      <h1 class="text-2xl font-semibold">Processes</h1>
      <p class="text-gray-600">Processes running on this instance</p>
    </div>
    <div class="flex gap-2">
      <PButton icon="pi pi-megaphone" label="Broadcast" size="small" severity="secondary" outlined
               :disabled="selected.length === 0" :badge="selected.length ? String(selected.length) : null" @click="openBroadcast" />
      <PButton icon="pi pi-refresh" label="Refresh" size="small" @click="refresh" />
    </div>
  </div>

  <div v-if="error" class="mb-4 flex items-start gap-2 rounded border border-red-300 bg-red-50 px-3 py-2 text-sm text-red-800">
    <i class="pi pi-exclamation-triangle mt-0.5"></i><span>{{ error }}</span>
  </div>
  <div v-if="notice" class="mb-4 flex items-start gap-2 rounded border border-green-300 bg-green-50 px-3 py-2 text-sm text-green-800">
    <i class="pi pi-check-circle mt-0.5"></i><span>{{ notice }}</span>
  </div>

  <Card class="shadow-sm">
    <template #content>
      <DataTable :value="rows" v-model:filters="filters" v-model:selection="selected" dataKey="Pid"
                 :paginator="true" :rows="25" :rowsPerPageOptions="[10, 25, 50, 100]"
                 @rowClick="openRow" @rowSelect="onRowSelect" @rowSelectAll="onSelectAll"
                 size="small" scrollable tableStyle="min-width: 70rem"
                 :globalFilterFields="columns.map(c => c.key)">
        <template #header>
          <div class="flex justify-between items-center">
            <span class="text-sm text-gray-500">Select processes to send them a broadcast message. Only processes that can receive one are selectable.</span>
            <IconField>
              <InputIcon><i class="pi pi-search" /></InputIcon>
              <InputText v-model="filters['global'].value" placeholder="Search" size="small" />
            </IconField>
          </div>
        </template>

        <Column selectionMode="multiple" :headerStyle="{ width: '1%' }" />

        <Column v-for="col in columns" :key="col.key" :field="col.key" :header="col.label" :sortable="!!col.sortable"
                :headerStyle="{ whiteSpace: 'nowrap' }">
          <template #body="{ data }">
            <Tag v-if="col.type === 'boolean'" :value="data[col.key] ? 'Yes' : 'No'" :severity="data[col.key] ? 'success' : 'secondary'" />
            <Tag v-else-if="col.key === 'State'" :value="data.State"
                 :severity="data.State === 'SUSP' ? 'warn' : data.State === 'RUN' ? 'success' : 'secondary'" />
            <span v-else class="truncate block max-w-xs" :title="data[col.key]">{{ data[col.key] }}</span>
          </template>
        </Column>

        <Column header="" :headerStyle="{ width: '1%' }" frozen alignFrozen="right">
          <template #body="{ data }">
            <div class="flex gap-1 justify-end">
              <PButton v-for="action in visibleActions(data)" :key="action.id"
                       :icon="action.icon || 'pi pi-bolt'" :severity="action.severity || 'secondary'"
                       text rounded size="small" v-tooltip.top="action.label" :aria-label="action.label"
                       @click.stop="runAction(action, data)" />
            </div>
          </template>
        </Column>
      </DataTable>
    </template>
  </Card>

  <ConfirmDialog v-model:visible="confirmVisible"
                 :title="(pending.action ? pending.action.label : '') + ' process'"
                 :message="'This will ' + (pending.action ? pending.action.label.toLowerCase() : '') + ' process ' + (pending.row ? pending.row.Pid : '') + ' on this instance.'"
                 :confirmLabel="pending.action ? pending.action.label : 'Confirm'"
                 @confirm="executePending" />

  <Dialog v-model:visible="broadcastVisible" modal header="Broadcast message" :style="{ width: '480px' }">
    <p class="text-sm text-gray-600 mb-3">The message is sent to {{ selected.length }} selected process{{ selected.length === 1 ? '' : 'es' }}: {{ selected.map(r => r.Pid).join(', ') }}</p>
    <div class="flex flex-col gap-1">
      <label class="text-sm font-medium" for="p-message">Message</label>
      <Textarea id="p-message" v-model="broadcastMessage" rows="4" fluid autoResize />
    </div>
    <template #footer>
      <div class="flex justify-end gap-2">
        <PButton label="Cancel" severity="secondary" outlined size="small" @click="broadcastVisible = false" />
        <PButton label="Send" icon="pi pi-send" size="small" :loading="sending" :disabled="!broadcastMessage" @click="sendBroadcast" />
      </div>
    </template>
  </Dialog>
</div>
}

}
