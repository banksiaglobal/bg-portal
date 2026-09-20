/// Create or edit a security resource: description and public permission. System
/// resources can be edited but not deleted.
Class Portal.Resource.Edit Extends Portal.Page
{

Parameter RESOURCE = "%Admin_Secure";

Parameter PAGEID = "resource.edit";

Parameter TITLE = "Resource";

Property resource As %DynamicObject;

Property isNew As %Boolean [ InitialExpression = 1 ];

/// R/W/U as an array for the SelectButton; joined back into PublicPermission on save.
Property publicPerms As %DynamicArray [ InitialExpression = {[]} ];

Property permOptions As %DynamicArray [ InitialExpression = {[{"label": "Read", "value": "R"}, {"label": "Write", "value": "W"}, {"label": "Use", "value": "U"}]} ];

Property error As %String;

Property saving As %Boolean [ InitialExpression = 0 ];

Method %OnNew() As %Status
{
    set name = $get(%request.Data("name", 1))
    set ..resource = ""
    if name '= "" {
        set ..resource = ##class(Portal.Resource.Service).Get(name)
        set ..isNew = '$isobject(..resource)
    }
    if '$isobject(..resource) {
        set ..resource = {"Name": (name), "Description": "", "PublicPermission": "", "ResourceType": "", "AllowDelete": true}
    } else {
        set row = ##class(Portal.Resource.Service).Find(name)
        set ..resource.ResourceType = $select($isobject(row): row.ResourceType, 1: "")
        do ..resource.%Set("AllowDelete", $select($isobject(row): row.AllowDelete, 1: 1), "boolean")
    }
    for i = 1:1:$length(..resource.PublicPermission) {
        do ..publicPerms.%Push($extract(..resource.PublicPermission, i))
    }
    return $$$OK
}

ClassMethod SaveResource(json As %String) As %String [ WebMethod ]
{
    set sc = ##class(Portal.Resource.Service).Save({}.%FromJSON(json))
    return ..ActionResult(sc)
}

ClientMethod save() [ Language = javascript ]
{
    this.error = '';
    this.saving = true;
    this.resource.PublicPermission = ['R', 'W', 'U'].filter(p => this.publicPerms.includes(p)).join('');
    const result = JSON.parse(await this.SaveResource(JSON.stringify(this.resource)));
    this.saving = false;
    if (!result.ok) {
        this.error = result.error;
        return;
    }
    location.href = "Portal.Resource.List.cls";
}

ClientMethod cancel() [ Language = javascript ]
{
    location.href = "Portal.Resource.List.cls";
}

XData Template [ MimeType = text/vue ]
{
<div class="max-w-3xl">
  <div class="flex justify-between items-center mb-4">
    <div>
      <h1 class="text-2xl font-semibold">{{ isNew ? 'New resource' : resource.Name }}</h1>
      <p v-if="!isNew" class="text-gray-600">{{ resource.ResourceType }} resource{{ resource.AllowDelete ? '' : ' (system-defined)' }}</p>
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
      <div class="grid grid-cols-1 gap-4">
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium" for="r-name">Name</label>
          <InputText id="r-name" v-model="resource.Name" :disabled="!isNew" />
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium" for="r-desc">Description</label>
          <InputText id="r-desc" v-model="resource.Description" />
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium">Public permission</label>
          <SelectButton v-model="publicPerms" :options="permOptions" optionLabel="label" optionValue="value" multiple />
          <span class="text-xs text-gray-500">Permissions every user holds on this resource without being granted a role. Leave empty for none.</span>
        </div>
      </div>
    </template>
  </Card>
</div>
}

}
