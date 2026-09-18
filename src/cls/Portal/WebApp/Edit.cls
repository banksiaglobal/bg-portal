/// Create or edit a web application. The form covers the common subset of
/// Security.Applications properties; everything else stays in the classic portal
/// until the corresponding screen is migrated.
Class Portal.WebApp.Edit Extends Portal.Page
{

Parameter RESOURCE = "%Admin_Secure";

Parameter PAGEID = "webapp.edit";

Parameter TITLE = "Web Application";

Property app As %DynamicObject;

Property isNew As %Boolean [ InitialExpression = 1 ];

Property namespaces As %DynamicArray;

Property error As %String;

Property saving As %Boolean [ InitialExpression = 0 ];

Method %OnNew() As %Status
{
    set name = $get(%request.Data("name", 1))
    set ..app = ""
    if name '= "" {
        set ..app = ##class(Portal.WebApp.Service).Get(name)
        set ..isNew = '$isobject(..app)
    }
    if '$isobject(..app) {
        set ..app = {"Name": (name), "NameSpace": "", "Description": "", "Enabled": true, "DispatchClass": "", "Path": "",
                     "Resource": "", "Timeout": 900, "CSRFToken": false, "CookiePath": "", "CSPZENEnabled": true, "IsNameSpaceDefault": false}
    }
    set ..namespaces = ..ListNamespaces()
    return $$$OK
}

ClassMethod ListNamespaces() As %DynamicArray
{
    set out = []
    do ##class(%SYS.Namespace).ListAll(.list)
    set ns = ""
    for {
        set ns = $order(list(ns))
        quit:ns=""
        continue:$extract(ns)="^"
        do out.%Push(ns)
    }
    return out
}

ClassMethod SaveApp(json As %String) As %String [ WebMethod ]
{
    set sc = ##class(Portal.WebApp.Service).Save({}.%FromJSON(json))
    return ..ActionResult(sc)
}

ClientMethod save() [ Language = javascript ]
{
    this.error = '';
    this.saving = true;
    const result = JSON.parse(await this.SaveApp(JSON.stringify(this.app)));
    this.saving = false;
    if (!result.ok) {
        this.error = result.error;
        return;
    }
    location.href = "Portal.WebApp.List.cls";
}

ClientMethod cancel() [ Language = javascript ]
{
    location.href = "Portal.WebApp.List.cls";
}

XData Template [ MimeType = text/vue ]
{
<div class="max-w-3xl">
  <div class="flex justify-between items-center mb-4">
    <div>
      <h1 class="text-2xl font-semibold">{{ isNew ? 'New web application' : app.Name }}</h1>
      <p v-if="!isNew" class="text-gray-600">{{ app.TypeDisplay }} application</p>
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
        <div class="flex flex-col gap-1 md:col-span-2">
          <label class="text-sm font-medium" for="wa-name">Name</label>
          <InputText id="wa-name" v-model="app.Name" :disabled="!isNew" placeholder="/csp/myapp" />
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium" for="wa-ns">Namespace</label>
          <Select id="wa-ns" v-model="app.NameSpace" :options="namespaces" placeholder="Select namespace" />
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium" for="wa-resource">Resource</label>
          <InputText id="wa-resource" v-model="app.Resource" />
        </div>
        <div class="flex flex-col gap-1 md:col-span-2">
          <label class="text-sm font-medium" for="wa-desc">Description</label>
          <InputText id="wa-desc" v-model="app.Description" />
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium" for="wa-dispatch">Dispatch class</label>
          <InputText id="wa-dispatch" v-model="app.DispatchClass" placeholder="REST.Dispatch" />
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium" for="wa-path">Physical path</label>
          <InputText id="wa-path" v-model="app.Path" />
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium" for="wa-cookie">Cookie path</label>
          <InputText id="wa-cookie" v-model="app.CookiePath" />
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium" for="wa-timeout">Session timeout (s)</label>
          <InputText id="wa-timeout" v-model="app.Timeout" type="number" />
        </div>

        <div class="md:col-span-2 grid grid-cols-2 md:grid-cols-4 gap-3 mt-2">
          <label class="flex items-center gap-2 text-sm"><ToggleSwitch v-model="app.Enabled" /> Enabled</label>
          <label class="flex items-center gap-2 text-sm"><ToggleSwitch v-model="app.CSRFToken" /> CSRF token</label>
          <label class="flex items-center gap-2 text-sm"><ToggleSwitch v-model="app.CSPZENEnabled" /> CSP/Zen</label>
          <label class="flex items-center gap-2 text-sm"><ToggleSwitch v-model="app.IsNameSpaceDefault" /> Namespace default</label>
        </div>
      </div>
    </template>
  </Card>
</div>
}

}
