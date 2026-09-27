/// Adds a "Bulk change" toolbar action to the Users list (page.user.list.bulk-actions):
/// select any number of users, then set/clear their account flags and add/remove roles
/// and escalation roles in one dialog, applied to every selected user. Demonstrates the
/// `fields` extension to the bulk-actions slot (Portal.ListPage / Portal.Ext.Schema):
/// the flags use `tristate` fields (null = leave unchanged), and the role pickers resolve
/// their options live through optionsClass/optionsMethod rather than a snapshot baked
/// into the cached Contribute() output.
Class PortalExt.UserBulkEdit.Contribution Extends Portal.Ext.Contribution
{

Parameter ID = "com.banksiaglobal.portal.userbulkedit";

Parameter NAME = "User bulk edit";

Parameter VERSION = "1.0.0";

Parameter PUBLISHER = "Banksia Global";

Parameter HOMEPAGE = "https://github.com/banksia-global/iris-portal";

Parameter REQUIRES = "%Admin_Secure";

Parameter ORDER As INTEGER = 150;

ClassMethod Contribute(slot As %String) As %DynamicArray
{
    return:slot="page.user.list.bulk-actions" ..BulkActions()
    return []
}

ClassMethod BulkActions() As %DynamicArray
{
    return [{
        "id": "userbulkedit.change",
        "label": "Bulk change",
        "icon": "pi pi-users-cog",
        "severity": "secondary",
        "resource": "%Admin_Secure",
        "class": "PortalExt.UserBulkEdit.Service",
        "method": "Apply",
        "order": 10,
        "fields": (..Fields())
    }]
}

ClassMethod Fields() As %DynamicArray
{
    return [
        {"key": "Enabled", "label": "Enabled", "type": "tristate", "onLabel": "Enable", "offLabel": "Disable"},
        {"key": "AccountNeverExpires", "label": "Account never expires", "type": "tristate"},
        {"key": "PasswordNeverExpires", "label": "Password never expires", "type": "tristate"},
        {"key": "ChangePassword", "label": "Change password on next login", "type": "tristate"},
        {"key": "AddRoles", "label": "Add roles", "type": "multiselect", "placeholder": "No change",
         "optionsClass": "PortalExt.UserBulkEdit.Service", "optionsMethod": "RoleNames"},
        {"key": "RemoveRoles", "label": "Remove roles", "type": "multiselect", "placeholder": "No change",
         "optionsClass": "PortalExt.UserBulkEdit.Service", "optionsMethod": "RoleNames"},
        {"key": "AddEscalationRoles", "label": "Add escalation roles", "type": "multiselect", "placeholder": "No change",
         "optionsClass": "PortalExt.UserBulkEdit.Service", "optionsMethod": "RoleNames"},
        {"key": "RemoveEscalationRoles", "label": "Remove escalation roles", "type": "multiselect", "placeholder": "No change",
         "optionsClass": "PortalExt.UserBulkEdit.Service", "optionsMethod": "RoleNames"}
    ]
}

}
