/// Shell for every Portal.* page: top bar, collapsible side navigation, main outlet, footer.
/// All navigation and slot content comes from Portal.Ext.Registry, so the shell itself
/// is extended by contributing items, never by editing this class.
Class Portal.Layout Extends Banksia.Bloom.Component
{

Property username As %String [ InitialExpression = {##class(Portal.Context).UserName()} ];

Property systemName As %String [ InitialExpression = {##class(Portal.Context).SystemName()} ];

Property systemType As %String [ InitialExpression = {##class(Portal.Context).SystemType()} ];

Property version As %String [ InitialExpression = {##class(Portal.Context).Version()} ];

Property url As %String [ InitialExpression = {$piece(%request.URL, "/", *)} ];

Property safeMode As %Boolean [ InitialExpression = {##class(Portal.Ext.Registry).SafeMode()} ];

Property collapsed As %Boolean [ InitialExpression = 0 ];

Property navGroups As %DynamicArray;

Property topBarItems As %DynamicArray;

Property userMenuItems As %DynamicArray;

Property footerItems As %DynamicArray;

Method %OnNew() As %Status
{
    set ..navGroups = ..GroupNav(##class(Portal.Ext.Registry).Collect("shell.nav"))
    set ..topBarItems = ##class(Portal.Ext.Registry).Collect("shell.topbar")
    set ..userMenuItems = ##class(Portal.Ext.Registry).Collect("shell.user-menu")
    set ..footerItems = ##class(Portal.Ext.Registry).Collect("shell.footer")
    return $$$OK
}

/// Groups keep their first-seen order so a contribution can add to an existing group
/// without affecting where that group sits in the sidebar.
ClassMethod GroupNav(items As %DynamicArray) As %DynamicArray
{
    set groups = []
    set iter = items.%GetIterator()
    while iter.%GetNext(.i, .item) {
        set name = $select(item.group '= "": item.group, 1: "")
        if '$data(index("g" _ name)) {
            do groups.%Push({"name": (name), "items": []})
            set index("g" _ name) = groups.%Size() - 1
        }
        do groups.%Get(index("g" _ name)).items.%Push(item)
    }
    return groups
}

/// Bloom emits ClientMethods into `methods`, so lifecycle hooks are wired from the template (@vue:mounted).
ClientMethod init() [ Language = javascript ]
{
    if (window.innerWidth < 768) {
        this.collapsed = true;
        return;
    }
    const stored = localStorage.getItem('portal.sidebar.collapsed');
    this.collapsed = stored === '1';
}

ClientMethod toggleSidebar() [ Language = javascript ]
{
    this.collapsed = !this.collapsed;
    if (window.innerWidth >= 768) {
        localStorage.setItem('portal.sidebar.collapsed', this.collapsed ? '1' : '0');
    }
}

ClientMethod isActive(item) [ Language = javascript ]
{
    return this.url.split('?')[0] === item.url.split('?')[0];
}

ClientMethod toggleUserMenu(event) [ Language = javascript ]
{
    this.$refs.userMenu.toggle(event);
}

ClientMethod navigate(url) [ Language = javascript ]
{
    window.location.href = url;
}

ClientMethod typeSeverity() [ Language = javascript ]
{
    return { LIVE: 'danger', TEST: 'warn', DEV: 'success' }[this.systemType] || 'secondary';
}

XData Template [ MimeType = text/vue ]
{
<div class="min-h-screen flex flex-col bg-gray-100 text-gray-900" @vue:mounted="init">

  <header class="h-14 shrink-0 flex items-center justify-between gap-2 px-3 bg-white border-b border-gray-200 sticky top-0 z-40">
    <div class="flex items-center gap-3 min-w-0">
      <PButton icon="pi pi-bars" text rounded severity="secondary" aria-label="Toggle navigation" @click="toggleSidebar" />
      <a href="Portal.Home.cls" class="font-semibold text-lg whitespace-nowrap">BG Portal</a>
      <span class="hidden sm:inline text-gray-500 truncate">{{ systemName }}</span>
      <Tag :value="systemType" :severity="typeSeverity()" />
      <span v-if="safeMode" class="hidden sm:inline-flex">
        <Tag value="SAFE MODE" severity="secondary" />
      </span>
    </div>

    <div class="flex items-center gap-1 shrink-0">
      <a v-for="item in topBarItems" :key="item.id" :href="item.url"
         class="inline-flex items-center gap-1 px-2 py-1 rounded text-sm text-gray-700 hover:bg-gray-100">
        <i v-if="item.icon" :class="item.icon"></i><span class="hidden sm:inline">{{ item.label }}</span>
      </a>
      <span class="hidden sm:inline-flex">
        <PButton icon="pi pi-user" :label="username" text severity="secondary"
                 aria-haspopup="true" aria-controls="portal-user-menu" @click="toggleUserMenu" />
      </span>
      <span class="sm:hidden">
        <PButton icon="pi pi-user" text rounded severity="secondary"
                 aria-label="Account menu" aria-haspopup="true" aria-controls="portal-user-menu" @click="toggleUserMenu" />
      </span>
      <OverlayPanel ref="userMenu" id="portal-user-menu">
        <div class="sm:hidden px-2 py-1.5 mb-1 border-b border-gray-200 font-medium text-gray-900 truncate">{{ username }}</div>
        <ul class="min-w-[180px]">
          <li v-for="item in userMenuItems" :key="item.id"
              class="flex items-center gap-2 px-2 py-1.5 rounded cursor-pointer hover:bg-gray-100"
              @click="navigate(item.url)">
            <i v-if="item.icon" :class="item.icon"></i><span>{{ item.label }}</span>
          </li>
        </ul>
      </OverlayPanel>
    </div>
  </header>

  <div class="flex flex-1 min-h-0 relative">
    <div v-if="!collapsed" class="fixed inset-0 top-14 bg-black/40 z-20 md:hidden" @click="toggleSidebar"></div>

    <aside :class="['fixed md:static inset-y-0 top-14 md:top-0 left-0 z-30 md:z-auto w-64 shrink-0 bg-white border-r border-gray-200 transition-all duration-150 overflow-y-auto h-[calc(100vh-3.5rem)] md:h-auto',
                    collapsed ? '-translate-x-full md:translate-x-0 md:w-14' : 'translate-x-0 md:w-60']">
      <nav class="py-2">
        <div v-for="group in navGroups" :key="group.name" class="mb-2">
          <div v-if="group.name && !collapsed" class="px-4 pt-3 pb-1 text-xs font-semibold uppercase tracking-wide text-gray-400">{{ group.name }}</div>
          <div v-else-if="group.name" class="mt-3 mx-3 border-t border-gray-200"></div>
          <a v-for="item in group.items" :key="item.id" :href="item.url" :title="item.label"
             :class="['flex items-center gap-3 mx-2 px-2 py-2 rounded text-sm',
                      isActive(item) ? 'bg-blue-50 text-blue-700 font-medium' : 'text-gray-700 hover:bg-gray-100']"
             @click="collapsed || window.innerWidth >= 768 || toggleSidebar()">
            <i :class="[item.icon || 'pi pi-circle', 'text-base w-5 text-center']"></i>
            <span v-if="!collapsed" class="truncate">{{ item.label }}</span>
          </a>
        </div>
      </nav>
    </aside>

    <main class="flex-1 min-w-0 p-3 sm:p-6">
      <child-outlet></child-outlet>
    </main>
  </div>

  <footer class="min-h-10 shrink-0 flex flex-col sm:flex-row items-center sm:justify-between gap-1 sm:gap-4 px-4 py-2 sm:py-0 bg-white border-t border-gray-200 text-xs text-gray-500 text-center sm:text-left">
    <div class="flex flex-wrap items-center justify-center gap-x-4 gap-y-1">
      <span>&#169; <a href="https://banksiaglobal.com" target="_blank" rel="noopener" class="hover:text-gray-800">Banksia Global</a> 2026. <span class="hidden sm:inline">Professional services for InterSystems technologies.</span></span>
      <template v-for="item in footerItems" :key="item.id">
        <a v-if="item.url" :href="item.url" class="hover:text-gray-800">{{ item.label }}</a>
        <span v-else>{{ item.label }}</span>
      </template>
    </div>
    <div>{{ systemName }} &#183; Version {{ version }}</div>
  </footer>

</div>
}

}
