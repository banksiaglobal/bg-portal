/// Generic create/edit screen: a form described by field descriptors, saved through one
/// WebMethod. The fields are the union of what the subclass declares and what
/// Portal.Ext.Registry contributes for its PAGEID. A concrete edit page supplies:
///
///   Parameter PAGEID, TITLE, RESOURCE
///   Parameter NOUN        heading in create mode is "New <NOUN>"
///   Parameter LISTURL     where Save and Cancel return to
///   Parameter NAMEFIELD   key holding the identity (default "Name"); read-only once the object exists
///   Parameter NAMEPARAM   request parameter carrying the identity (default "name")
///   Parameter COLUMNS     1 or 2 grid columns (default 2)
///   Parameter MAXWIDTH    Tailwind max-width class of the form (default "max-w-3xl")
///   Method Fields() As %DynamicArray              built-in fields (instance method so options can reference lookups)
///   ClassMethod Load(name) As %DynamicObject      the object, or "" when it does not exist
///   ClassMethod Defaults() As %DynamicObject      seed object for create mode; must contain every key a field binds
///   ClassMethod Save(obj) As %Status              persist; receives the whole form object minus extension fields
///   Method OnLoad() As %Status                    optional; populate lookup properties (options) after the object is loaded
///   Method Subtitle() As %String                  optional; text under the heading in edit mode
///   XData ExtraTemplate                           optional; cards rendered after the form (custom tables, secondary operations)
///
/// Field shape: {key*, label*, type, order, section, colSpan, placeholder, help, options, clearable,
///               when, disabledIf, newOnly, existingOnly, class, loader, method, resource}
///   type       text (default) | number | password | date | textarea | select | multiselect | toggle | perms
///              "perms" edits an R/W/U permission string with a SelectButton
///   section    fields sharing a section render in one Card titled with it; "" is the untitled first card
///   colSpan    2 spans the row (4 for a toggle); toggles are gathered in a row at the end of their section
///   options    array, or the name of a page property holding the array (select/multiselect/perms)
///   when                     display expression, context {obj, isNew} (see Portal.Page.evalWhen)
///   disabledIf               {field, equals} evaluated against the object on the client
///   class/loader/method      extension persistence; see Portal.Ext.Contribution
///
/// Slots: page.<PAGEID>.fields and the widget slot .widgets.sidebar (column right of the form, ctx = obj).
Class Portal.EditPage Extends Portal.Page [ Abstract ]
{

Parameter NOUN = "item";

Parameter LISTURL;

Parameter NAMEFIELD = "Name";

Parameter NAMEPARAM = "name";

Parameter COLUMNS As INTEGER = 2;

Parameter MAXWIDTH = "max-w-3xl";

Property obj As %DynamicObject;

Property name As %String;

Property isNew As %Boolean [ InitialExpression = 1 ];

Property fields As %DynamicArray;

Property subtitle As %String;

Property noun As %String [ InitialExpression = {..#NOUN} ];

Property listUrl As %String [ InitialExpression = {..#LISTURL} ];

Property nameField As %String [ InitialExpression = {..#NAMEFIELD} ];

Property columns As %Integer [ InitialExpression = {..#COLUMNS} ];

Property maxWidth As %String [ InitialExpression = {..#MAXWIDTH} ];

Property permOptions As %DynamicArray [ InitialExpression = {[{"label": "Read", "value": "R"}, {"label": "Write", "value": "W"}, {"label": "Use", "value": "U"}]} ];

Property error As %String;

Property notice As %String;

Property saving As %Boolean [ InitialExpression = 0 ];

Method %OnNew() As %Status
{
    set ..name = $get(%request.Data(..#NAMEPARAM, 1))
    set ..obj = ""
    if ..name '= "" {
        set ..obj = ..Load(..name)
        set ..isNew = '$isobject(..obj)
    }
    if '$isobject(..obj) {
        set ..obj = ..Defaults()
        do ..obj.%Set(..#NAMEFIELD, ..name)
    }
    set sc = ..OnLoad()
    return:$$$ISERR(sc) sc
    set ..fields = ..BuildFields()
    set ..subtitle = ..Subtitle()
    return $$$OK
}

/// Built-in fields. Override.
Method Fields() As %DynamicArray
{
    return []
}

/// The object to edit, or "" when it does not exist. Override.
ClassMethod Load(name As %String) As %DynamicObject
{
    return ""
}

/// Seed object for create mode. Override.
ClassMethod Defaults() As %DynamicObject
{
    return {}
}

/// Persist the form object. Override.
ClassMethod Save(obj As %DynamicObject) As %Status
{
    return $$$ERROR($$$GeneralError, "Save is not implemented on " _ $classname())
}

Method OnLoad() As %Status
{
    return $$$OK
}

Method Subtitle() As %String
{
    return ""
}

/// Core fields plus registry fields, sorted. Extension fields are seeded on the object
/// here (through their loader) so the client binds a defined value.
Method BuildFields() As %DynamicArray
{
    set fields = ..Fields()
    set extra = ##class(Portal.Ext.Registry).Collect("page." _ ..#PAGEID _ ".fields")
    set iter = extra.%GetIterator()
    while iter.%GetNext(.i, .field) {
        set value = ""
        if ('..isNew) && (field.loader '= "") {
            try {
                set value = $classmethod(field.class, field.loader, ..name)
            } catch ex {
                set ^Portal.Ext("error", field.source, "Fields:" _ field.key) = ex.DisplayString()
            }
        }
        do ..obj.%Set(field.key, value)
        do fields.%Push(field)
    }
    return ##class(Portal.Ext.Registry).Sort(fields)
}

/// Saves the page's own object, then hands each extension field's value to its
/// contribution. Extension keys never reach Save().
ClassMethod SaveObject(json As %String) As %String [ WebMethod ]
{
    set obj = {}.%FromJSON(json)
    set name = obj.%Get(..#NAMEFIELD)
    set extra = ##class(Portal.Ext.Registry).Collect("page." _ ..#PAGEID _ ".fields")
    set iter = extra.%GetIterator()
    while iter.%GetNext(.i, .field) {
        set values(field.key) = obj.%Get(field.key)
        do obj.%Remove(field.key)
    }
    set sc = ..Save(obj)
    return:$$$ISERR(sc) ..ActionResult(sc)
    set iter = extra.%GetIterator()
    while iter.%GetNext(.i, .field) {
        continue:field.method=""
        try {
            set sc = $classmethod(field.class, field.method, name, $get(values(field.key)))
        } catch ex {
            set sc = ex.AsStatus()
        }
        if $$$ISERR(sc) {
            set ^Portal.Ext("error", field.source, "Fields:" _ field.key) = $system.Status.GetErrorText(sc)
            return ..ActionResult(sc)
        }
    }
    return ..ActionResult($$$OK)
}

ClientMethod submit() [ Language = javascript ]
{
    this.error = '';
    this.saving = true;
    const result = JSON.parse(await this.SaveObject(JSON.stringify(this.obj)));
    this.saving = false;
    if (!result.ok) {
        this.error = result.error;
        return;
    }
    location.href = this.listUrl;
}

ClientMethod cancel() [ Language = javascript ]
{
    location.href = this.listUrl;
}

/// Section names in order of first appearance; "" (the untitled card) is always first.
ClientMethod sectionList() [ Language = javascript ]
{
    const names = [''];
    for (const f of this.fields) {
        const s = f.section || '';
        if (!names.includes(s)) names.push(s);
    }
    return names.filter(s => this.inputs(s).length || this.toggles(s).length);
}

ClientMethod isVisible(f) [ Language = javascript ]
{
    if (f.newOnly && !this.isNew) return false;
    if (f.existingOnly && this.isNew) return false;
    return this.passes(f, { obj: this.obj, isNew: this.isNew });
}

ClientMethod isDisabled(f) [ Language = javascript ]
{
    if (f.key === this.nameField && !this.isNew) return true;
    return !!f.disabledIf && this.obj[f.disabledIf.field] === f.disabledIf.equals;
}

ClientMethod inputs(section) [ Language = javascript ]
{
    return this.fields.filter(f => (f.section || '') === section && f.type !== 'toggle' && this.isVisible(f));
}

ClientMethod toggles(section) [ Language = javascript ]
{
    return this.fields.filter(f => (f.section || '') === section && f.type === 'toggle' && this.isVisible(f));
}

ClientMethod optionsOf(f) [ Language = javascript ]
{
    return Array.isArray(f.options) ? f.options : (this[f.options] || []);
}

ClientMethod permsOf(value) [ Language = javascript ]
{
    return (value || '').split('');
}

ClientMethod setPerms(key, values) [ Language = javascript ]
{
    this.obj[key] = ['R', 'W', 'U'].filter(p => values.includes(p)).join('');
}

/// Cards rendered after the form.
XData ExtraTemplate [ MimeType = text/vue ]
{
}

XData Template [ MimeType = text/vue ]
{
<div :class="slotWidgets('sidebar', obj).length ? 'max-w-6xl' : maxWidth">
  <div class="flex justify-between items-center mb-4">
    <div>
      <h1 class="text-2xl font-semibold">{{ isNew ? 'New ' + noun : obj[nameField] }}</h1>
      <p v-if="!isNew && subtitle" class="text-gray-600">{{ subtitle }}</p>
    </div>
    <div class="flex gap-2">
      <PButton label="Cancel" severity="secondary" size="small" outlined @click="cancel" />
      <PButton label="Save" icon="pi pi-check" size="small" :loading="saving" @click="submit" />
    </div>
  </div>

  <div v-if="error" class="mb-4 flex items-start gap-2 rounded border border-red-300 bg-red-50 px-3 py-2 text-sm text-red-800">
    <i class="pi pi-exclamation-triangle mt-0.5"></i><span>{{ error }}</span>
  </div>
  <div v-if="notice" class="mb-4 flex items-start gap-2 rounded border border-green-300 bg-green-50 px-3 py-2 text-sm text-green-800">
    <i class="pi pi-check-circle mt-0.5"></i><span>{{ notice }}</span>
  </div>

  <div class="flex gap-4 items-start">
  <div class="flex-1 min-w-0">
  <Card v-for="(section, index) in sectionList()" :key="section" class="shadow-sm" :class="{ 'mt-4': index > 0 }">
    <template v-if="section" #title><span class="text-base">{{ section }}</span></template>
    <template #content>
      <div class="grid grid-cols-1 gap-4" :class="{ 'md:grid-cols-2': columns === 2 }">
        <div v-for="f in inputs(section)" :key="f.key" class="flex flex-col gap-1" :class="{ 'md:col-span-2': f.colSpan === 2 }">
          <label class="text-sm font-medium" :for="'f-' + f.key">{{ f.label }}</label>
          <InputText v-if="f.type === 'number'" :id="'f-' + f.key" v-model="obj[f.key]" type="number" :placeholder="f.placeholder" :disabled="isDisabled(f)" />
          <InputText v-else-if="f.type === 'date'" :id="'f-' + f.key" v-model="obj[f.key]" :placeholder="f.placeholder || 'YYYY-MM-DD'" :disabled="isDisabled(f)" />
          <Password v-else-if="f.type === 'password'" :id="'f-' + f.key" :inputId="'f-' + f.key" v-model="obj[f.key]" :feedback="false" toggleMask fluid :disabled="isDisabled(f)" />
          <Textarea v-else-if="f.type === 'textarea'" :id="'f-' + f.key" v-model="obj[f.key]" rows="4" fluid autoResize :placeholder="f.placeholder" :disabled="isDisabled(f)" />
          <Select v-else-if="f.type === 'select'" :id="'f-' + f.key" v-model="obj[f.key]" :options="optionsOf(f)" :placeholder="f.placeholder" :showClear="!!f.clearable" :disabled="isDisabled(f)" />
          <MultiSelect v-else-if="f.type === 'multiselect'" :id="'f-' + f.key" v-model="obj[f.key]" :options="optionsOf(f)" filter :placeholder="f.placeholder" display="chip" :disabled="isDisabled(f)" />
          <SelectButton v-else-if="f.type === 'perms'" :modelValue="permsOf(obj[f.key])" @update:modelValue="v => setPerms(f.key, v)"
                        :options="Array.isArray(f.options) ? f.options : permOptions" optionLabel="label" optionValue="value" multiple :disabled="isDisabled(f)" />
          <InputText v-else :id="'f-' + f.key" v-model="obj[f.key]" :placeholder="f.placeholder" :disabled="isDisabled(f)" />
          <span v-if="f.help" class="text-xs text-gray-500">{{ f.help }}</span>
        </div>

        <div v-if="toggles(section).length" class="grid grid-cols-2 md:grid-cols-4 gap-3 mt-2" :class="{ 'md:col-span-2': columns === 2 }">
          <label v-for="f in toggles(section)" :key="f.key" class="flex items-center gap-2 text-sm"
                 :class="{ 'md:col-span-2': f.colSpan === 2, 'md:col-span-4': f.colSpan === 4 }">
            <ToggleSwitch v-model="obj[f.key]" :disabled="isDisabled(f)" /> {{ f.label }}
          </label>
        </div>
      </div>
    </template>
  </Card>

  @include ExtraTemplate
  </div>

  <ext-slot name="sidebar" ctx="obj" layout="stack" class="w-80 shrink-0" />
  </div>
</div>
}

}
