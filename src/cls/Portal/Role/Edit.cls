/// Create or edit a role: description, escalation flag, granted roles and the
/// resource/permission pairs it carries. Members holding the role are shown read-only.
Class Portal.Role.Edit Extends Portal.Page
{

Parameter RESOURCE = "%Admin_Secure";

Parameter PAGEID = "role.edit";

Parameter TITLE = "Role";

Property role As %DynamicObject;

Property isNew As %Boolean [ InitialExpression = 1 ];

Property roles As %DynamicArray;

Property resources As %DynamicArray;

Property members As %DynamicArray [ InitialExpression = {[]} ];

Property permOptions As %DynamicArray [ InitialExpression = {[{"label": "R", "value": "R"}, {"label": "W", "value": "W"}, {"label": "U", "value": "U"}]} ];

Property newResource As %String;

Property error As %String;

Property saving As %Boolean [ InitialExpression = 0 ];

Method %OnNew() As %Status
{
    set name = $get(%request.Data("name", 1))
    set ..role = ""
    if name '= "" {
        set ..role = ##class(Portal.Role.Service).Get(name)
        set ..isNew = '$isobject(..role)
    }
    if '$isobject(..role) {
        set ..role = {"Name": (name), "Description": "", "EscalationOnly": false, "GrantedRoles": [], "Resources": []}
    } else {
        set ..members = ##class(Portal.Role.Service).Members(name)
    }
    set ..roles = ##class(Portal.Role.Service).Names()
    set ..resources = ##class(Portal.Resource.Service).Names()
    return $$$OK
}

ClassMethod SaveRole(json As %String) As %String [ WebMethod ]
{
    set sc = ##class(Portal.Role.Service).Save({}.%FromJSON(json))
    return ..ActionResult(sc)
}

ClientMethod save() [ Language = javascript ]
{
    this.error = '';
    this.saving = true;
    const result = JSON.parse(await this.SaveRole(JSON.stringify(this.role)));
    this.saving = false;
    if (!result.ok) {
        this.error = result.error;
        return;
    }
    location.href = "Portal.Role.List.cls";
}

ClientMethod cancel() [ Language = javascript ]
{
    location.href = "Portal.Role.List.cls";
}

/// Resources not yet on the role, for the add picker.
ClientMethod availableResources() [ Language = javascript ]
{
    const used = new Set(this.role.Resources.map(r => r.Name));
    return this.resources.filter(r => !used.has(r));
}

ClientMethod addResource() [ Language = javascript ]
{
    if (!this.newResource) return;
    this.role.Resources.push({ Name: this.newResource, Permissions: 'U' });
    this.newResource = '';
}

ClientMethod removeResource(index) [ Language = javascript ]
{
    this.role.Resources.splice(index, 1);
}

ClientMethod perms(row) [ Language = javascript ]
{
    return (row.Permissions || '').split('');
}

ClientMethod setPerms(row, values) [ Language = javascript ]
{
    row.Permissions = ['R', 'W', 'U'].filter(p => values.includes(p)).join('');
}

XData Template [ MimeType = text/vue ]
{
<div class="max-w-4xl">
  <div class="flex justify-between items-center mb-4">
    <div>
      <h1 class="text-2xl font-semibold">{{ isNew ? 'New role' : role.Name }}</h1>
      <p v-if="!isNew" class="text-gray-600">{{ role.Description }}</p>
    </div>
    <div class="flex gap-2">
      <PButton label="Cancel" severity="secondary" size="small" outlined @click="cancel" />
      <PButton label="Save" icon="pi pi-check" size="small" :loading="saving" @click="save" />
    </div>
  </div>

  <div v-if="error" class="mb-4 flex items-start gap-2 rounded border border-red-300 bg-red-50 px-3 py-2 text-sm text-red-800">
    <i class="pi pi-exclamation-triangle mt-0.5"></i><span>{{ error }}</span>
  </div>

  <Card class="shadow-sm">
    <template #content>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium" for="ro-name">Name</label>
          <InputText id="ro-name" v-model="role.Name" :disabled="!isNew" />
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium" for="ro-desc">Description</label>
          <InputText id="ro-desc" v-model="role.Description" />
        </div>
        <div class="flex flex-col gap-1 md:col-span-2">
          <label class="text-sm font-medium" for="ro-granted">Granted roles</label>
          <MultiSelect id="ro-granted" v-model="role.GrantedRoles" :options="roles.filter(r => r !== role.Name)" filter placeholder="No roles" display="chip" />
        </div>
        <div class="md:col-span-2">
          <label class="flex items-center gap-2 text-sm"><ToggleSwitch v-model="role.EscalationOnly" /> Escalation only (can be held only through escalation, not assigned at login)</label>
        </div>
      </div>
    </template>
  </Card>

  <Card class="shadow-sm mt-4">
    <template #title><span class="text-base">Resources</span></template>
    <template #content>
      <DataTable :value="role.Resources" size="small" dataKey="Name">
        <template #empty><span class="text-sm text-gray-500">No resources on this role.</span></template>
        <Column field="Name" header="Resource" sortable />
        <Column header="Permissions" :headerStyle="{ width: '1%' }">
          <template #body="{ data }">
            <SelectButton :modelValue="perms(data)" @update:modelValue="v => setPerms(data, v)" :options="permOptions" optionLabel="label" optionValue="value" multiple size="small" />
          </template>
        </Column>
        <Column header="" :headerStyle="{ width: '1%' }">
          <template #body="{ index }">
            <PButton icon="pi pi-trash" severity="danger" text rounded size="small" v-tooltip.top="'Remove'" aria-label="Remove" @click="removeResource(index)" />
          </template>
        </Column>
      </DataTable>
      <div class="flex items-end gap-2 mt-3">
        <div class="flex flex-col gap-1 grow">
          <label class="text-sm font-medium" for="ro-add">Add resource</label>
          <Select id="ro-add" v-model="newResource" :options="availableResources()" filter placeholder="Select a resource" showClear />
        </div>
        <PButton label="Add" icon="pi pi-plus" size="small" severity="secondary" :disabled="!newResource" @click="addResource" />
      </div>
    </template>
  </Card>

  <Card v-if="!isNew" class="shadow-sm mt-4">
    <template #title><span class="text-base">Members</span></template>
    <template #content>
      <DataTable :value="members" size="small" :paginator="members.length > 25" :rows="25">
        <template #empty><span class="text-sm text-gray-500">Nobody holds this role.</span></template>
        <Column field="Name" header="Name" sortable />
        <Column field="Type" header="Type" sortable />
        <Column header="Admin option" :headerStyle="{ width: '1%' }">
          <template #body="{ data }">
            <Tag :value="data.AdminOption && data.AdminOption !== '0' ? 'Yes' : 'No'" :severity="data.AdminOption && data.AdminOption !== '0' ? 'success' : 'secondary'" />
          </template>
        </Column>
      </DataTable>
    </template>
  </Card>
</div>
}

}
