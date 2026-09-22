/// Sidebar widget on the user edit page: reads the object being edited through the
/// `ctx` prop, so it follows the form live without any server round trip.
Class PortalExt.Example.UserSidebar Extends Banksia.Bloom.Component
{

Parameter PROPS = "ctx";

XData Template [ MimeType = text/vue ]
{
<dl class="grid grid-cols-[max-content_1fr] gap-x-4 gap-y-1 text-sm">
  <dt class="text-gray-500">Name</dt><dd>{{ ctx.Name || '—' }}</dd>
  <dt class="text-gray-500">Roles</dt><dd>{{ (ctx.Roles || []).length }}</dd>
  <dt class="text-gray-500">Enabled</dt><dd><Tag :value="ctx.Enabled ? 'Yes' : 'No'" :severity="ctx.Enabled ? 'success' : 'secondary'" /></dd>
  <dt class="text-gray-500">Note</dt><dd class="break-words">{{ ctx.ExampleNote || '—' }}</dd>
</dl>
}

}
