/// Create or edit a user. The form covers the subset of Security.Users properties
/// exposed by the %Api.Admin user endpoint; anything else stays in the classic portal.
Class Portal.User.Edit Extends Portal.EditPage
{

Parameter RESOURCE = "%Admin_Secure";

Parameter PAGEID = "user.edit";

Parameter TITLE = "User";

Parameter NOUN = "user";

Parameter LISTURL = "Portal.User.List.cls";

Property namespaces As %DynamicArray;

Property roles As %DynamicArray;

Property newPassword As %String;

Method Fields() As %DynamicArray
{
    return [
        {"key": "Name", "label": "Name", "order": 10},
        {"key": "Password", "label": "Password", "type": "password", "order": 20, "newOnly": true},
        {"key": "FullName", "label": "Full name", "order": 30},
        {"key": "Comment", "label": "Comment", "order": 40, "colSpan": 2},
        {"key": "EmailAddress", "label": "Email", "order": 50},
        {"key": "PhoneNumber", "label": "Mobile phone", "order": 60},
        {"key": "NameSpace", "label": "Startup namespace", "type": "select", "options": "namespaces", "placeholder": "None", "clearable": true, "order": 70},
        {"key": "Routine", "label": "Startup routine", "order": 80},
        {"key": "Roles", "label": "Roles", "type": "multiselect", "options": "roles", "placeholder": "No roles", "order": 90},
        {"key": "EscalationRoles", "label": "Escalation roles", "type": "multiselect", "options": "roles", "placeholder": "No roles", "order": 100},
        {"key": "ExpirationDate", "label": "Expiration date", "type": "date", "order": 110, "disabledIf": {"field": "AccountNeverExpires", "equals": true}},
        {"key": "Enabled", "label": "Enabled", "type": "toggle", "order": 200},
        {"key": "AccountNeverExpires", "label": "Account never expires", "type": "toggle", "order": 210},
        {"key": "PasswordNeverExpires", "label": "Password never expires", "type": "toggle", "order": 220},
        {"key": "ChangePassword", "label": "Change password on next login", "type": "toggle", "order": 230}
    ]
}

ClassMethod Load(name As %String) As %DynamicObject
{
    return ##class(Portal.User.Service).Get(name)
}

ClassMethod Defaults() As %DynamicObject
{
    return {"Name": "", "Password": "", "FullName": "", "Comment": "", "EmailAddress": "", "PhoneNumber": "",
            "NameSpace": "", "Routine": "", "Roles": [], "EscalationRoles": [], "ExpirationDate": "",
            "Enabled": true, "AccountNeverExpires": true, "PasswordNeverExpires": false, "ChangePassword": false}
}

ClassMethod Save(obj As %DynamicObject) As %Status
{
    return ##class(Portal.User.Service).Save(obj)
}

Method OnLoad() As %Status
{
    set ..namespaces = ##class(Portal.WebApp.Edit).ListNamespaces()
    set ..roles = ##class(Portal.User.Service).RoleNames()
    return $$$OK
}

Method Subtitle() As %String
{
    return ..obj.FullName
}

ClassMethod SetPassword(name As %String, newPassword As %String) As %String [ WebMethod ]
{
    set sc = ##class(Portal.User.Service).ChangePassword(name, newPassword)
    return ..ActionResult(sc)
}

ClientMethod changePassword() [ Language = javascript ]
{
    this.error = '';
    this.notice = '';
    const result = JSON.parse(await this.SetPassword(this.obj.Name, this.newPassword));
    if (!result.ok) {
        this.error = result.error;
        return;
    }
    this.newPassword = '';
    this.notice = 'Password changed.';
}

XData ExtraTemplate [ MimeType = text/vue ]
{
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
}

}
