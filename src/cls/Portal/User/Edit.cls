/// Create or edit a user. The form covers the subset of Security.Users properties
/// exposed by the %Api.Admin user endpoint; anything else stays in the classic portal.
Class Portal.User.Edit Extends Portal.Page
{

Parameter RESOURCE = "%Admin_Secure";

Parameter PAGEID = "user.edit";

Parameter TITLE = "User";

Property user As %DynamicObject;

Property isNew As %Boolean [ InitialExpression = 1 ];

Property namespaces As %DynamicArray;

Property roles As %DynamicArray;

Property newPassword As %String;

Property error As %String;

Property notice As %String;

Property saving As %Boolean [ InitialExpression = 0 ];

Method %OnNew() As %Status
{
    set name = $get(%request.Data("name", 1))
    set ..user = ""
    if name '= "" {
        set ..user = ##class(Portal.User.Service).Get(name)
        set ..isNew = '$isobject(..user)
    }
    if '$isobject(..user) {
        set ..user = {"Name": (name), "Password": "", "FullName": "", "Comment": "", "EmailAddress": "", "PhoneNumber": "",
                      "NameSpace": "", "Routine": "", "Roles": [], "EscalationRoles": [], "ExpirationDate": "",
                      "Enabled": true, "AccountNeverExpires": true, "PasswordNeverExpires": false, "ChangePassword": false}
    }
    set ..namespaces = ##class(Portal.WebApp.Edit).ListNamespaces()
    set ..roles = ##class(Portal.User.Service).RoleNames()
    return $$$OK
}

ClassMethod SaveUser(json As %String) As %String [ WebMethod ]
{
    set sc = ##class(Portal.User.Service).Save({}.%FromJSON(json))
    return ..ActionResult(sc)
}

ClassMethod SetPassword(name As %String, newPassword As %String) As %String [ WebMethod ]
{
    set sc = ##class(Portal.User.Service).ChangePassword(name, newPassword)
    return ..ActionResult(sc)
}

ClientMethod save() [ Language = javascript ]
{
    this.error = '';
    this.saving = true;
    const result = JSON.parse(await this.SaveUser(JSON.stringify(this.user)));
    this.saving = false;
    if (!result.ok) {
        this.error = result.error;
        return;
    }
    location.href = "Portal.User.List.cls";
}

ClientMethod changePassword() [ Language = javascript ]
{
    this.error = '';
    this.notice = '';
    const result = JSON.parse(await this.SetPassword(this.user.Name, this.newPassword));
    if (!result.ok) {
        this.error = result.error;
        return;
    }
    this.newPassword = '';
    this.notice = 'Password changed.';
}

ClientMethod cancel() [ Language = javascript ]
{
    location.href = "Portal.User.List.cls";
}

XData Template [ MimeType = text/vue ]
{
<div class="max-w-3xl">
  <div class="flex justify-between items-center mb-4">
    <div>
      <h1 class="text-2xl font-semibold">{{ isNew ? 'New user' : user.Name }}</h1>
      <p v-if="!isNew" class="text-gray-600">{{ user.FullName }}</p>
    </div>
    <div class="flex gap-2">
      <PButton label="Cancel" severity="secondary" size="small" outlined @click="cancel" />
      <PButton label="Save" icon="pi pi-check" size="small" :loading="saving" @click="save" />
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
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium" for="u-name">Name</label>
          <InputText id="u-name" v-model="user.Name" :disabled="!isNew" />
        </div>
        <div v-if="isNew" class="flex flex-col gap-1">
          <label class="text-sm font-medium" for="u-password">Password</label>
          <Password id="u-password" v-model="user.Password" :feedback="false" toggleMask fluid inputId="u-password" />
        </div>
        <div class="flex flex-col gap-1" :class="{ 'md:col-span-2': !isNew }">
          <label class="text-sm font-medium" for="u-fullname">Full name</label>
          <InputText id="u-fullname" v-model="user.FullName" />
        </div>
        <div class="flex flex-col gap-1 md:col-span-2">
          <label class="text-sm font-medium" for="u-comment">Comment</label>
          <InputText id="u-comment" v-model="user.Comment" />
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium" for="u-email">Email</label>
          <InputText id="u-email" v-model="user.EmailAddress" type="email" />
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium" for="u-phone">Mobile phone</label>
          <InputText id="u-phone" v-model="user.PhoneNumber" />
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium" for="u-ns">Startup namespace</label>
          <Select id="u-ns" v-model="user.NameSpace" :options="namespaces" placeholder="None" showClear />
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium" for="u-routine">Startup routine</label>
          <InputText id="u-routine" v-model="user.Routine" />
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium" for="u-roles">Roles</label>
          <MultiSelect id="u-roles" v-model="user.Roles" :options="roles" filter placeholder="No roles" display="chip" />
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium" for="u-escroles">Escalation roles</label>
          <MultiSelect id="u-escroles" v-model="user.EscalationRoles" :options="roles" filter placeholder="No roles" display="chip" />
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium" for="u-expires">Expiration date</label>
          <InputText id="u-expires" v-model="user.ExpirationDate" placeholder="YYYY-MM-DD" :disabled="user.AccountNeverExpires" />
        </div>

        <div class="md:col-span-2 grid grid-cols-2 md:grid-cols-4 gap-3 mt-2">
          <label class="flex items-center gap-2 text-sm"><ToggleSwitch v-model="user.Enabled" /> Enabled</label>
          <label class="flex items-center gap-2 text-sm"><ToggleSwitch v-model="user.AccountNeverExpires" /> Account never expires</label>
          <label class="flex items-center gap-2 text-sm"><ToggleSwitch v-model="user.PasswordNeverExpires" /> Password never expires</label>
          <label class="flex items-center gap-2 text-sm"><ToggleSwitch v-model="user.ChangePassword" /> Change password on next login</label>
        </div>
      </div>
    </template>
  </Card>

  <Card v-if="!isNew" class="shadow-sm mt-4">
    <template #title><span class="text-base">Change password</span></template>
    <template #content>
      <div class="flex items-end gap-2">
        <div class="flex flex-col gap-1 grow">
          <label class="text-sm font-medium" for="u-newpwd">New password</label>
          <Password id="u-newpwd" v-model="newPassword" :feedback="false" toggleMask fluid inputId="u-newpwd" />
        </div>
        <PButton label="Change password" icon="pi pi-key" size="small" severity="secondary" :disabled="!newPassword" @click="changePassword" />
      </div>
    </template>
  </Card>
</div>
}

}
