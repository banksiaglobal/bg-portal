/// User list. Columns and row actions are the union of the core set declared here
/// and whatever Portal.Ext.Registry contributes for page id "user.list".
Class Portal.User.List Extends Portal.Page
{

Parameter RESOURCE = "%Admin_Secure";

Parameter PAGEID = "user.list";

Parameter TITLE = "Users";

Property rows As %DynamicArray;

Property columns As %DynamicArray;

Property actions As %DynamicArray;

Property filters As %DynamicObject [ InitialExpression = {{"global": {"value": ""}}} ];

Property pending As %DynamicObject [ InitialExpression = {{}} ];

Property confirmVisible As %Boolean [ InitialExpression = 0 ];

Property error As %String;

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
        {"key": "Name", "label": "Name", "sortable": true, "order": 10},
        {"key": "FullName", "label": "Full name", "sortable": true, "order": 20},
        {"key": "Type", "label": "Type", "sortable": true, "order": 30},
        {"key": "Enabled", "label": "Enabled", "type": "boolean", "sortable": true, "order": 40},
        {"key": "Namespace", "label": "Startup namespace", "sortable": true, "order": 50},
        {"key": "Routine", "label": "Startup routine", "order": 60}
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
    set rows = ##class(Portal.User.Service).List()
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

ClientMethod createNew() [ Language = javascript ]
{
    location.href = "Portal.User.Edit.cls";
}

ClientMethod openRow(event) [ Language = javascript ]
{
    location.href = "Portal.User.Edit.cls?name=" + encodeURIComponent(event.data.Name);
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
    const result = JSON.parse(await this.InvokeAction(action.id, JSON.stringify(row)));
    if (!result.ok) {
        this.error = result.error;
        return;
    }
    this.rows = JSON.parse(await this.Reload());
}

XData Template [ MimeType = text/vue ]
{
<div>
  <div class="flex justify-between items-center mb-4">
    <div>
      <h1 class="text-2xl font-semibold">Users</h1>
      <p class="text-gray-600">User accounts defined on this instance</p>
    </div>
    <PButton icon="pi pi-plus" label="New user" size="small" @click="createNew" />
  </div>

  <div v-if="error" class="mb-4 flex items-start gap-2 rounded border border-red-300 bg-red-50 px-3 py-2 text-sm text-red-800">
    <i class="pi pi-exclamation-triangle mt-0.5"></i><span>{{ error }}</span>
  </div>

  <Card class="shadow-sm">
    <template #content>
      <DataTable :value="rows" v-model:filters="filters" dataKey="Name"
                 :paginator="true" :rows="25" :rowsPerPageOptions="[10, 25, 50, 100]"
                 selectionMode="single" @rowSelect="openRow" size="small" scrollable tableStyle="min-width: 60rem"
                 :globalFilterFields="columns.map(c => c.key)">
        <template #header>
          <div class="flex justify-end">
            <IconField>
              <InputIcon><i class="pi pi-search" /></InputIcon>
              <InputText v-model="filters['global'].value" placeholder="Search" size="small" />
            </IconField>
          </div>
        </template>

        <Column v-for="col in columns" :key="col.key" :field="col.key" :header="col.label" :sortable="!!col.sortable"
                :headerStyle="{ whiteSpace: 'nowrap' }">
          <template #body="{ data }">
            <Tag v-if="col.type === 'boolean'" :value="data[col.key] ? 'Yes' : 'No'" :severity="data[col.key] ? 'success' : 'secondary'" />
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
                 :title="(pending.action ? pending.action.label : '') + ' user'"
                 :message="'This will ' + (pending.action ? pending.action.label.toLowerCase() : '') + ' ' + (pending.row ? pending.row.Name : '') + ' on this instance.'"
                 :confirmLabel="pending.action ? pending.action.label : 'Confirm'"
                 @confirm="executePending" />
</div>
}

}
