/// Process list. Columns and row actions are the union of the core set declared here
/// and whatever Portal.Ext.Registry contributes for page id "process.list".
/// Rows can be multi-selected for a broadcast message; only processes that report
/// CanReceiveBroadcast are selectable.
Class Portal.Process.List Extends Portal.ListPage
{

Parameter RESOURCE = "%Admin_Operate";

Parameter PAGEID = "process.list";

Parameter TITLE = "Processes";

Parameter SUBTITLE = "Processes running on this instance";

Parameter ROWURL = "Portal.Process.Detail.cls?id={Pid}";

Parameter ROWKEY = "Pid";

Parameter CONFIRMNOUN = " process";

Parameter SELECTION = "multiple";

Parameter SHOWREFRESH As BOOLEAN = 1;

Parameter HINT = "Select processes to send them a broadcast message. Only processes that can receive one are selectable.";

Parameter MINWIDTH = "70rem";

Property broadcastVisible As %Boolean [ InitialExpression = 0 ];

Property broadcastMessage As %String;

Property sending As %Boolean [ InitialExpression = 0 ];

ClassMethod CoreColumns() As %DynamicArray
{
    return [
        {"key": "Pid", "label": "PID", "sortable": true, "order": 10},
        {"key": "Job", "label": "Job", "sortable": true, "order": 20},
        {"key": "Username", "label": "User", "sortable": true, "order": 30},
        {"key": "Nspace", "label": "Namespace", "sortable": true, "order": 40},
        {"key": "Routine", "label": "Routine", "sortable": true, "order": 50},
        {"key": "State", "label": "State", "type": "tag", "severities": {"SUSP": "warn", "RUN": "success"}, "sortable": true, "order": 60},
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

ClassMethod Rows() As %DynamicArray
{
    return ##class(Portal.Process.Service).List()
}

ClassMethod Broadcast(pidsJson As %String, message As %String) As %String [ WebMethod ]
{
    set sc = ##class(Portal.Process.Service).Broadcast([].%FromJSON(pidsJson), message)
    return ..ActionResult(sc)
}

ClientMethod describeRow(row) [ Language = javascript ]
{
    return row ? 'process ' + row.Pid : '';
}

ClientMethod rowSelectable(row) [ Language = javascript ]
{
    return !!row.CanReceiveBroadcast;
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

XData ToolbarTemplate [ MimeType = text/vue ]
{
<PButton icon="pi pi-megaphone" label="Broadcast" size="small" severity="secondary" outlined
         :disabled="selected.length === 0" :badge="selected.length ? String(selected.length) : null" @click="openBroadcast" />
}

XData ExtraTemplate [ MimeType = text/vue ]
{
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
}

}
