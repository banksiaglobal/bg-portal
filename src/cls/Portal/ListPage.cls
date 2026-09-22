/// Generic list screen: a filterable, paginated table whose columns and row actions are
/// the union of what the subclass declares and what Portal.Ext.Registry contributes for
/// its PAGEID. A concrete list supplies the data and a handful of parameters:
///
///   Parameter PAGEID, TITLE, SUBTITLE, RESOURCE
///   Parameter CREATEURL   "New" button target; empty hides the button (NEWLABEL is its caption)
///   Parameter ROWURL      row click target with {Field} placeholders (see resolveUrl); empty disables row click
///   Parameter ROWKEY      field used as the table dataKey (default "Name")
///   Parameter CONFIRMNOUN suffix for the confirm dialog title, e.g. " user"
///   Parameter SELECTION   "multiple" adds a checkbox column bound to `selected` (also on when bulk actions exist)
///   Parameter SHOWREFRESH 1 adds a Refresh button
///   Parameter HINT        text shown left of the search box
///   Parameter MINWIDTH    table min-width (CSS length)
///   ClassMethod CoreColumns() As %DynamicArray   built-in columns (same shape as a contribution's Columns)
///   ClassMethod Rows() As %DynamicArray          raw rows from the service
///   XData ToolbarTemplate / ExtraTemplate        optional extra buttons / dialogs (Vue markup)
///   ClientMethod describeRow(row)                optional; text used in the confirm message
///   ClientMethod rowSelectable(row)              optional; rows it rejects cannot be ticked (multi-select)
///
/// Column shape: {key*, label*, order, sortable, type, severities, class, method, component, resource}
///   type "boolean" renders a Yes/No Tag, "tag" a Tag whose severity is looked up in
///   `severities` by value, "mono" a monospace span; anything else is plain text.
///   component names a Banksia.Bloom.Component (PROPS = "row,col") that renders the cell instead.
///   when (context {row}) hides a column; for columns the context is {rows} (all rows).
/// Slots: page.<PAGEID>.columns, .actions (row buttons, when-context {row}), .bulk-actions
/// (toolbar buttons on the selection, when-context {rows}; class/method take the selected rows
/// as %DynamicArray and return %Status; dispatched through InvokeBulkAction with a resource
/// re-check and an audit row of the selected keys) and the widget slot .widgets.footer below
/// the table (ctx = rows).
Class Portal.ListPage Extends Portal.Page [ Abstract ]
{

Parameter SUBTITLE;

Parameter CREATEURL;

Parameter NEWLABEL = "New";

Parameter ROWURL;

Parameter ROWKEY = "Name";

Parameter CONFIRMNOUN;

Parameter SELECTION;

Parameter SHOWREFRESH As BOOLEAN = 0;

Parameter HINT;

Parameter MINWIDTH = "60rem";

Property title As %String [ InitialExpression = {..#TITLE} ];

Property subtitle As %String [ InitialExpression = {..#SUBTITLE} ];

Property createUrl As %String [ InitialExpression = {..#CREATEURL} ];

Property newLabel As %String [ InitialExpression = {..#NEWLABEL} ];

Property rowUrl As %String [ InitialExpression = {..#ROWURL} ];

Property rowKey As %String [ InitialExpression = {..#ROWKEY} ];

Property confirmNoun As %String [ InitialExpression = {..#CONFIRMNOUN} ];

Property multi As %Boolean [ InitialExpression = {..#SELECTION = "multiple"} ];

Property bulkActions As %DynamicArray;

Property showRefresh As %Boolean [ InitialExpression = {..#SHOWREFRESH} ];

Property hint As %String [ InitialExpression = {..#HINT} ];

Property minWidth As %String [ InitialExpression = {..#MINWIDTH} ];

Property rows As %DynamicArray;

Property columns As %DynamicArray;

Property actions As %DynamicArray;

Property filters As %DynamicObject [ InitialExpression = {{"global": {"value": ""}}} ];

Property pending As %DynamicObject [ InitialExpression = {{}} ];

Property confirmVisible As %Boolean [ InitialExpression = 0 ];

Property selected As %DynamicArray [ InitialExpression = {[]} ];

Property error As %String;

Property notice As %String;

Method %OnNew() As %Status
{
    set ..columns = ..BuildColumns()
    set ..actions = ##class(Portal.Ext.Registry).Collect("page." _ ..#PAGEID _ ".actions")
    set ..bulkActions = ##class(Portal.Ext.Registry).Collect("page." _ ..#PAGEID _ ".bulk-actions")
    set:..bulkActions.%Size() ..multi = 1
    set ..rows = ..BuildRows(..columns)
    return $$$OK
}

/// Dispatcher for bulk actions: the registry re-applies the resource check, and the
/// audit row records the selected row keys rather than every row.
ClassMethod InvokeBulkAction(actionId As %String, rowsJson As %String) As %String [ WebMethod ]
{
    set action = ##class(Portal.Ext.Registry).FindItem("page." _ ..#PAGEID _ ".bulk-actions", actionId)
    return:'$isobject(action) ..ActionResult($$$ERROR($$$GeneralError, "Unknown bulk action '" _ actionId _ "'"))
    set rows = [].%FromJSON(rowsJson)
    set keys = []
    set iter = rows.%GetIterator()
    while iter.%GetNext(.i, .row) { do keys.%Push(row.%Get(..#ROWKEY)) }
    set ^Portal.Audit($increment(^Portal.Audit)) = $listbuild($horolog, $username, ..#PAGEID, actionId, action.source, keys.%ToJSON())
    set sc = $classmethod(action.class, action.method, rows)
    return ..ActionResult(sc)
}

/// Core columns may use components too.
ClassMethod ExtraComponents() As %List
{
    set list = ##super()
    set iter = ..CoreColumns().%GetIterator()
    while iter.%GetNext(.i, .col) {
        continue:col.component=""
        continue:'##class(Portal.Ext.Registry).ValidComponent(col.component, $classname(), "Columns:" _ col.key)
        set list = list _ $listbuild(col.component)
    }
    return list
}

/// Built-in columns. Override.
ClassMethod CoreColumns() As %DynamicArray
{
    return []
}

/// Raw rows from the service. Override.
ClassMethod Rows() As %DynamicArray
{
    return []
}

ClassMethod BuildColumns() As %DynamicArray
{
    set columns = ..CoreColumns()
    set extra = ##class(Portal.Ext.Registry).Collect("page." _ ..#PAGEID _ ".columns")
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
    set rows = ..Rows()
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
    location.href = this.createUrl;
}

ClientMethod openRow(event) [ Language = javascript ]
{
    if (!this.rowUrl) return;
    location.href = this.resolveUrl(this.rowUrl, event.data);
}

/// Reloads the rows and drops selected rows that no longer exist.
ClientMethod refresh() [ Language = javascript ]
{
    this.error = '';
    this.rows = JSON.parse(await this.Reload());
    const live = new Set(this.rows.map(r => r[this.rowKey]));
    this.selected = Array.isArray(this.selected) ? this.selected.filter(r => live.has(r[this.rowKey])) : [];
}

ClientMethod visibleColumns() [ Language = javascript ]
{
    return this.columns.filter(c => this.passes(c, { rows: this.rows }));
}

ClientMethod visibleActions(row) [ Language = javascript ]
{
    return this.actions.filter(a => this.passes(a, { row }));
}

ClientMethod visibleBulkActions() [ Language = javascript ]
{
    return this.bulkActions.filter(a => this.passes(a, { rows: this.selected }));
}

ClientMethod runBulk(action) [ Language = javascript ]
{
    this.pending = { action, rows: this.selected.slice() };
    if (action.confirm) {
        this.confirmVisible = true;
        return;
    }
    await this.executePending();
}

/// Text for the confirm dialog: the row, or the size of the selection.
ClientMethod describePending() [ Language = javascript ]
{
    if (this.pending.rows) return this.pending.rows.length + ' selected row' + (this.pending.rows.length === 1 ? '' : 's');
    return this.describeRow(this.pending.row);
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

/// Runs the pending row or bulk action, then reloads the rows whether it succeeded or
/// not: a bulk action may have changed some rows before failing on one.
ClientMethod executePending() [ Language = javascript ]
{
    const { action, row, rows } = this.pending;
    this.error = '';
    this.notice = '';
    const result = rows
        ? JSON.parse(await this.InvokeBulkAction(action.id, JSON.stringify(rows)))
        : JSON.parse(await this.InvokeAction(action.id, JSON.stringify(row)));
    if (rows && result.ok) this.selected = [];
    await this.refresh();
    if (!result.ok) {
        this.error = result.error;
        return;
    }
    if (rows) this.notice = action.label + ': ' + rows.length + ' row' + (rows.length === 1 ? '' : 's') + ' processed.';
}

/// How a row is named in the confirm dialog. Override for a richer description.
ClientMethod describeRow(row) [ Language = javascript ]
{
    return row ? String(row[this.rowKey]) : '';
}

ClientMethod tagSeverity(col, value) [ Language = javascript ]
{
    return (col.severities && col.severities[value]) || 'secondary';
}

/// Which rows may be ticked. Override to restrict the selection: rows it rejects get no
/// checkbox and are filtered out of every selection update (select-all included).
ClientMethod rowSelectable(row) [ Language = javascript ]
{
    return true;
}

ClientMethod isSelected(row) [ Language = javascript ]
{
    return this.selected.some(r => r[this.rowKey] === row[this.rowKey]);
}

ClientMethod toggleRow(row, on) [ Language = javascript ]
{
    if (!this.rowSelectable(row)) return;
    const rest = this.selected.filter(r => r[this.rowKey] !== row[this.rowKey]);
    this.selected = on ? rest.concat([row]) : rest;
}

/// Every selection change the table emits (checkbox, header checkbox, row click) goes
/// through here, so an unselectable row can never end up in `selected`.
ClientMethod onSelectionUpdate(value) [ Language = javascript ]
{
    if (!this.multi) return;
    this.selected = (Array.isArray(value) ? value : []).filter(r => this.rowSelectable(r));
}

/// Extra buttons in the page header, rendered after the built-in ones.
XData ToolbarTemplate [ MimeType = text/vue ]
{
}

/// Extra markup (dialogs, cards) rendered after the table.
XData ExtraTemplate [ MimeType = text/vue ]
{
}

XData Template [ MimeType = text/vue ]
{
<div>
  <div class="flex justify-between items-center mb-4">
    <div>
      <h1 class="text-2xl font-semibold">{{ title }}</h1>
      <p class="text-gray-600">{{ subtitle }}</p>
    </div>
    <div class="flex gap-2">
      <PButton v-for="action in visibleBulkActions()" :key="action.id" :label="action.label" :icon="action.icon || 'pi pi-bolt'"
               :severity="action.severity || 'secondary'" size="small" outlined :disabled="selected.length === 0"
               :badge="selected.length ? String(selected.length) : null" @click="runBulk(action)" />
      @include ToolbarTemplate
      <PButton v-if="showRefresh" icon="pi pi-refresh" label="Refresh" size="small" @click="refresh" />
      <PButton v-if="createUrl" icon="pi pi-plus" :label="newLabel" size="small" @click="createNew" />
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
      <DataTable :value="rows" v-model:filters="filters" :selection="selected" @update:selection="onSelectionUpdate" :dataKey="rowKey"
                 :paginator="true" :rows="50" :rowsPerPageOptions="[10, 25, 50, 100]"
                 :selectionMode="!multi && rowUrl ? 'single' : null"
                 @rowSelect="multi ? null : openRow($event)" @rowClick="multi ? openRow($event) : null"
                 size="small" scrollable :tableStyle="{ minWidth: minWidth }"
                 :globalFilterFields="columns.map(c => c.key)">
        <template #header>
          <div class="flex justify-between items-center">
            <span class="text-sm text-gray-500">{{ hint }}</span>
            <IconField>
              <InputIcon><i class="pi pi-search" /></InputIcon>
              <InputText v-model="filters['global'].value" placeholder="Search" size="small" />
            </IconField>
          </div>
        </template>

        <Column v-if="multi" selectionMode="multiple" :headerStyle="{ width: '1%' }">
          <template #body="{ data }">
            <span v-if="rowSelectable(data)" @click.stop>
              <Checkbox :modelValue="isSelected(data)" :binary="true" @update:modelValue="v => toggleRow(data, v)" :aria-label="'Select ' + data[rowKey]" />
            </span>
          </template>
        </Column>

        <Column v-for="col in visibleColumns()" :key="col.key" :field="col.key" :header="col.label" :sortable="!!col.sortable"
                :headerStyle="{ whiteSpace: 'nowrap' }">
          <template #body="{ data }">
            <component v-if="col.component" :is="cmp(col.component)" :row="data" :col="col" />
            <Tag v-else-if="col.type === 'boolean'" :value="data[col.key] ? 'Yes' : 'No'" :severity="data[col.key] ? 'success' : 'secondary'" />
            <Tag v-else-if="col.type === 'tag'" :value="data[col.key]" :severity="tagSeverity(col, data[col.key])" />
            <span v-else-if="col.type === 'mono'" class="font-mono">{{ data[col.key] }}</span>
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

  <ext-slot name="footer" ctx="rows" class="mt-4" />

  <ConfirmDialog v-model:visible="confirmVisible"
                 :title="(pending.action ? pending.action.label : '') + confirmNoun"
                 :message="'This will ' + (pending.action ? pending.action.label.toLowerCase() : '') + ' ' + describePending() + ' on this instance.'"
                 :confirmLabel="pending.action ? pending.action.label : 'Confirm'"
                 @confirm="executePending" />

  @include ExtraTemplate
</div>
}

}
