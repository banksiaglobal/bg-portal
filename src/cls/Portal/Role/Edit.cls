/// Create or edit a role: description, escalation flag, granted roles and the
/// resource/permission pairs it carries. Members holding the role are shown read-only.
Class Portal.Role.Edit Extends Portal.EditPage
{

Parameter RESOURCE = "%Admin_Secure";

Parameter PAGEID = "role.edit";

Parameter TITLE = "Role";

Parameter NOUN = "role";

Parameter LISTURL = "Portal.Role.List.cls";

Parameter MAXWIDTH = "max-w-4xl";

/// Other roles, for the granted-roles picker.
Property roles As %DynamicArray;

Property resources As %DynamicArray;

Property members As %DynamicArray [ InitialExpression = {[]} ];

Property permOptionsShort As %DynamicArray [ InitialExpression = {[{"label": "R", "value": "R"}, {"label": "W", "value": "W"}, {"label": "U", "value": "U"}]} ];

Property newResource As %String;

Method Fields() As %DynamicArray
{
    return [
        {"key": "Name", "label": "Name", "order": 10},
        {"key": "Description", "label": "Description", "order": 20},
        {"key": "GrantedRoles", "label": "Granted roles", "type": "multiselect", "options": "roles", "placeholder": "No roles", "colSpan": 2, "order": 30},
        {"key": "EscalationOnly", "label": "Escalation only (can be held only through escalation, not assigned at login)", "type": "toggle", "colSpan": 4, "order": 40}
    ]
}

ClassMethod Load(name As %String) As %DynamicObject
{
    return ##class(Portal.Role.Service).Get(name)
}

ClassMethod Defaults() As %DynamicObject
{
    return {"Name": "", "Description": "", "EscalationOnly": false, "GrantedRoles": [], "Resources": []}
}

ClassMethod Save(obj As %DynamicObject) As %Status
{
    return ##class(Portal.Role.Service).Save(obj)
}

Method OnLoad() As %Status
{
    set:'..isNew ..members = ##class(Portal.Role.Service).Members(..name)
    set ..roles = []
    set all = ##class(Portal.Role.Service).Names()
    set iter = all.%GetIterator()
    while iter.%GetNext(.i, .role) {
        do:role'=..name ..roles.%Push(role)
    }
    set ..resources = ##class(Portal.Resource.Service).Names()
    return $$$OK
}

Method Subtitle() As %String
{
    return ..obj.Description
}

/// Resources not yet on the role, for the add picker.
ClientMethod availableResources() [ Language = javascript ]
{
    const used = new Set(this.obj.Resources.map(r => r.Name));
    return this.resources.filter(r => !used.has(r));
}

ClientMethod addResource() [ Language = javascript ]
{
    if (!this.newResource) return;
    this.obj.Resources.push({ Name: this.newResource, Permissions: 'U' });
    this.newResource = '';
}

ClientMethod removeResource(index) [ Language = javascript ]
{
    this.obj.Resources.splice(index, 1);
}

ClientMethod setRowPerms(row, values) [ Language = javascript ]
{
    row.Permissions = ['R', 'W', 'U'].filter(p => values.includes(p)).join('');
}

XData ExtraTemplate [ MimeType = text/vue ]
{
<Card class="shadow-sm mt-4">
  <template #title><span class="text-base">Resources</span></template>
  <template #content>
    <DataTable :value="obj.Resources" size="small" dataKey="Name">
      <template #empty><span class="text-sm text-gray-500">No resources on this role.</span></template>
      <Column field="Name" header="Resource" sortable />
      <Column header="Permissions" :headerStyle="{ width: '1%' }">
        <template #body="{ data }">
          <SelectButton :modelValue="permsOf(data.Permissions)" @update:modelValue="v => setRowPerms(data, v)" :options="permOptionsShort" optionLabel="label" optionValue="value" multiple size="small" />
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
    <DataTable :value="members" size="small" :paginator="members.length > 50" :rows="50">
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
}

}
