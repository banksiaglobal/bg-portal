/// Detail of one process: identity, user, client, resource statistics and local
/// variables, with Suspend / Resume / Terminate. Processes cannot be edited, so this
/// is the read-only counterpart of the Edit pages under Portal.User / Portal.WebApp.
Class Portal.Process.Detail Extends Portal.Page
{

Parameter RESOURCE = "%Admin_Operate";

Parameter PAGEID = "process.detail";

Parameter TITLE = "Process";

Property pid As %String;

Property process As %DynamicObject;

Property found As %Boolean [ InitialExpression = 0 ];

Property confirmVisible As %Boolean [ InitialExpression = 0 ];

Property pendingAction As %String;

Property busy As %Boolean [ InitialExpression = 0 ];

Property error As %String;

Property notice As %String;

Method %OnNew() As %Status
{
    set ..pid = $get(%request.Data("id", 1))
    set ..process = ""
    set:..pid'="" ..process = ##class(Portal.Process.Service).Get(..pid)
    set ..found = $isobject(..process)
    set:'..found ..process = {"Pid": (..pid), "Variables": []}
    return $$$OK
}

ClassMethod Load(pid As %String) As %String [ WebMethod ]
{
    set process = ##class(Portal.Process.Service).Get(pid)
    return:'$isobject(process) "null"
    return process.%ToJSON()
}

ClassMethod SuspendProcess(pid As %String) As %String [ WebMethod ]
{
    return ..ActionResult(##class(Portal.Process.Service).Suspend({"Pid": (pid)}))
}

ClassMethod ResumeProcess(pid As %String) As %String [ WebMethod ]
{
    return ..ActionResult(##class(Portal.Process.Service).Resume({"Pid": (pid)}))
}

ClassMethod TerminateProcess(pid As %String) As %String [ WebMethod ]
{
    return ..ActionResult(##class(Portal.Process.Service).Terminate({"Pid": (pid)}))
}

ClientMethod refresh() [ Language = javascript ]
{
    this.error = '';
    const process = JSON.parse(await this.Load(this.pid));
    this.found = process !== null;
    if (this.found) this.process = process;
}

ClientMethod suspend() [ Language = javascript ]
{
    await this.run('Suspend');
}

ClientMethod resume() [ Language = javascript ]
{
    await this.run('Resume');
}

ClientMethod terminate() [ Language = javascript ]
{
    this.pendingAction = 'Terminate';
    this.confirmVisible = true;
}

ClientMethod confirmPending() [ Language = javascript ]
{
    await this.run(this.pendingAction);
}

ClientMethod run(action) [ Language = javascript ]
{
    this.error = '';
    this.notice = '';
    this.busy = true;
    const result = JSON.parse(await this[action + 'Process'](this.pid));
    this.busy = false;
    if (!result.ok) {
        this.error = result.error;
        return;
    }
    if (action === 'Terminate') {
        location.href = "Portal.Process.List.cls";
        return;
    }
    this.notice = 'Process ' + this.pid + ' ' + action.toLowerCase() + 'd.';
    await this.refresh();
}

ClientMethod back() [ Language = javascript ]
{
    location.href = "Portal.Process.List.cls";
}

ClientMethod list(value) [ Language = javascript ]
{
    return Array.isArray(value) && value.length ? value.join(', ') : '—';
}

ClientMethod num(value) [ Language = javascript ]
{
    return typeof value === 'number' ? value.toLocaleString() : (value ?? '');
}

XData Template [ MimeType = text/vue ]
{
<div class="max-w-5xl">
  <div class="flex justify-between items-center mb-4">
    <div>
      <h1 class="text-2xl font-semibold flex items-center gap-3">
        Process {{ pid }}
        <Tag v-if="found" :value="process.State" :severity="process.State === 'SUSP' ? 'warn' : process.State === 'RUN' ? 'success' : 'secondary'" />
      </h1>
      <p v-if="found" class="text-gray-600">{{ process.UserName || process.OSUserName }} · {{ process.NameSpace || '—' }} · {{ process.Routine || '—' }}</p>
    </div>
    <div class="flex gap-2">
      <PButton label="Back" severity="secondary" size="small" outlined @click="back" />
      <PButton icon="pi pi-refresh" label="Refresh" severity="secondary" size="small" @click="refresh" />
      <PButton v-if="found && process.State === 'SUSP'" label="Resume" icon="pi pi-play" severity="success" size="small" :loading="busy" @click="resume" />
      <PButton v-else-if="found && process.CanBeSuspended" label="Suspend" icon="pi pi-pause" severity="warn" size="small" :loading="busy" @click="suspend" />
      <PButton v-if="found && process.CanBeTerminated" label="Terminate" icon="pi pi-times" severity="danger" size="small" :loading="busy" @click="terminate" />
    </div>
  </div>

  <div v-if="error" class="mb-4 flex items-start gap-2 rounded border border-red-300 bg-red-50 px-3 py-2 text-sm text-red-800">
    <i class="pi pi-exclamation-triangle mt-0.5"></i><span>{{ error }}</span>
  </div>
  <div v-if="notice" class="mb-4 flex items-start gap-2 rounded border border-green-300 bg-green-50 px-3 py-2 text-sm text-green-800">
    <i class="pi pi-check-circle mt-0.5"></i><span>{{ notice }}</span>
  </div>

  <div v-if="!found" class="rounded border border-amber-300 bg-amber-50 px-3 py-2 text-sm text-amber-800">
    Process {{ pid }} does not exist (any more) on this instance.
  </div>

  <div v-else class="grid grid-cols-1 md:grid-cols-2 gap-4">
    <Card class="shadow-sm">
      <template #title><span class="text-base">Identity</span></template>
      <template #content>
        <dl class="grid grid-cols-[max-content_1fr] gap-x-4 gap-y-1 text-sm">
          <dt class="text-gray-500">PID</dt><dd>{{ process.Pid }} <span v-if="process.PidExternal != process.Pid" class="text-gray-500">(external {{ process.PidExternal }})</span></dd>
          <dt class="text-gray-500">Parent PID</dt><dd>{{ process.ParentPid || '—' }}</dd>
          <dt class="text-gray-500">Job number</dt><dd>{{ process.JobNumber }}</dd>
          <dt class="text-gray-500">Job type</dt><dd>{{ process.JobType }}</dd>
          <dt class="text-gray-500">Priority</dt><dd>{{ process.Priority }}</dd>
          <dt class="text-gray-500">Started (UTC)</dt><dd>{{ process.StartTimeUTC }}</dd>
          <dt class="text-gray-500">Namespace</dt><dd>{{ process.NameSpace || '—' }}</dd>
          <dt class="text-gray-500">Routine</dt><dd>{{ process.Routine || '—' }}</dd>
          <dt class="text-gray-500">Location</dt><dd class="font-mono break-all">{{ process.Location || '—' }}</dd>
          <dt class="text-gray-500">Current line</dt><dd class="font-mono break-all">{{ process.CurrentLineAndRoutine || '—' }}</dd>
          <dt class="text-gray-500">Source line</dt><dd class="font-mono break-all">{{ process.CurrentSrcLine || '—' }}</dd>
          <dt class="text-gray-500">Principal device</dt><dd>{{ process.PrincipalDevice || '—' }}</dd>
          <dt class="text-gray-500">Current device</dt><dd>{{ process.CurrentDevice || '—' }}</dd>
          <dt class="text-gray-500">Open devices</dt><dd>{{ list(process.OpenDevices) }}</dd>
          <dt class="text-gray-500">In transaction</dt><dd><Tag :value="process.InTransaction ? 'Yes' : 'No'" :severity="process.InTransaction ? 'warn' : 'secondary'" /></dd>
          <dt class="text-gray-500">Ghost</dt><dd><Tag :value="process.IsGhost ? 'Yes' : 'No'" :severity="process.IsGhost ? 'warn' : 'secondary'" /></dd>
        </dl>
      </template>
    </Card>

    <div class="flex flex-col gap-4">
      <Card class="shadow-sm">
        <template #title><span class="text-base">User</span></template>
        <template #content>
          <dl class="grid grid-cols-[max-content_1fr] gap-x-4 gap-y-1 text-sm">
            <dt class="text-gray-500">User name</dt><dd>{{ process.UserName || '—' }}</dd>
            <dt class="text-gray-500">OS user</dt><dd>{{ process.OSUserName || '—' }}</dd>
            <dt class="text-gray-500">User info</dt><dd>{{ process.UserInfo || '—' }}</dd>
            <dt class="text-gray-500">Login roles</dt><dd>{{ list(process.LoginRoles) }}</dd>
            <dt class="text-gray-500">Roles</dt><dd>{{ list(process.Roles) }}</dd>
            <dt class="text-gray-500">Escalated roles</dt><dd>{{ list(process.EscalatedRoles) }}</dd>
            <dt class="text-gray-500">License user</dt><dd>{{ process.LicenseUserId || '—' }}</dd>
            <dt class="text-gray-500">CSP session</dt><dd class="font-mono break-all">{{ process.CSPSessionID || '—' }}</dd>
          </dl>
        </template>
      </Card>

      <Card class="shadow-sm">
        <template #title><span class="text-base">Client</span></template>
        <template #content>
          <dl class="grid grid-cols-[max-content_1fr] gap-x-4 gap-y-1 text-sm">
            <dt class="text-gray-500">Node</dt><dd>{{ process.ClientNodeName || '—' }}</dd>
            <dt class="text-gray-500">IP address</dt><dd>{{ process.ClientIPAddress || '—' }}</dd>
            <dt class="text-gray-500">Executable</dt><dd>{{ process.ClientExecutableName || '—' }}</dd>
            <dt class="text-gray-500">Startup node</dt><dd>{{ process.StartupClientNodeName || '—' }}</dd>
            <dt class="text-gray-500">Startup IP</dt><dd>{{ process.StartupClientIPAddress || '—' }}</dd>
          </dl>
        </template>
      </Card>
    </div>

    <Card class="shadow-sm md:col-span-2">
      <template #title><span class="text-base">Statistics</span></template>
      <template #content>
        <dl class="grid grid-cols-2 md:grid-cols-4 gap-x-6 gap-y-3 text-sm">
          <div><dt class="text-gray-500">Commands executed</dt><dd class="text-lg">{{ num(process.CommandsExecuted) }}</dd></div>
          <div><dt class="text-gray-500">CPU time (ms)</dt><dd class="text-lg">{{ num(process.CPUTime) }}</dd></div>
          <div><dt class="text-gray-500">Global references</dt><dd class="text-lg">{{ num(process.GlobalReferences) }}</dd></div>
          <div><dt class="text-gray-500">Global updates</dt><dd class="text-lg">{{ num(process.GlobalUpdates) }}</dd></div>
          <div><dt class="text-gray-500">Disk reads</dt><dd class="text-lg">{{ num(process.GlobalDiskReads) }}</dd></div>
          <div><dt class="text-gray-500">Global blocks</dt><dd class="text-lg">{{ num(process.GlobalBlocks) }}</dd></div>
          <div><dt class="text-gray-500">Data block writes</dt><dd class="text-lg">{{ num(process.DataBlockWrites) }}</dd></div>
          <div><dt class="text-gray-500">Journal entries</dt><dd class="text-lg">{{ num(process.JournalEntries) }}</dd></div>
          <div><dt class="text-gray-500">Private global refs</dt><dd class="text-lg">{{ num(process.PrivateGlobalReferences) }}</dd></div>
          <div><dt class="text-gray-500">Private global updates</dt><dd class="text-lg">{{ num(process.PrivateGlobalUpdates) }}</dd></div>
          <div><dt class="text-gray-500">Private global blocks</dt><dd class="text-lg">{{ num(process.PrivateGlobalBlockCount) }}</dd></div>
          <div><dt class="text-gray-500">Last global reference</dt><dd class="font-mono break-all">{{ process.LastGlobalReference || '—' }}</dd></div>
          <div><dt class="text-gray-500">Memory allocated (KB)</dt><dd class="text-lg">{{ num(process.MemoryAllocated) }}</dd></div>
          <div><dt class="text-gray-500">Memory used (KB)</dt><dd class="text-lg">{{ num(process.MemoryUsed) }}</dd></div>
          <div><dt class="text-gray-500">Memory peak (KB)</dt><dd class="text-lg">{{ num(process.MemoryPeak) }}</dd></div>
        </dl>
      </template>
    </Card>

    <Card class="shadow-sm md:col-span-2">
      <template #title><span class="text-base">Variables</span></template>
      <template #content>
        <DataTable :value="process.Variables" size="small" scrollable scrollHeight="400px" :paginator="process.Variables.length > 50" :rows="50">
          <template #empty><span class="text-sm text-gray-500">No variables (or the process cannot be examined).</span></template>
          <Column field="Name" header="Name" sortable :headerStyle="{ width: '30%' }">
            <template #body="{ data }"><span class="font-mono">{{ data.Name }}</span></template>
          </Column>
          <Column field="Value" header="Value">
            <template #body="{ data }"><span class="font-mono break-all">{{ data.Value }}</span></template>
          </Column>
        </DataTable>
      </template>
    </Card>
  </div>

  <ConfirmDialog v-model:visible="confirmVisible"
                 :title="pendingAction + ' process'"
                 :message="'This will ' + pendingAction.toLowerCase() + ' process ' + pid + ' on this instance.'"
                 :confirmLabel="pendingAction"
                 @confirm="confirmPending" />
</div>
}

}
