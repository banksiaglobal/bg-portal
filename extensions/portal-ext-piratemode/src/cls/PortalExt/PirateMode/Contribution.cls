/// Fun demo extension: reskins the portal like a pirate's log (black background, rough
/// parchment-edged panels, a decorative headline font) and turns "Save" buttons into
/// "YARRR!" and boolean Yes/No tags into "YARRR!" / a skull, everywhere in the portal.
/// One shell.head item does it all (Portal.Ext.Schema "head" kind): `url` pulls in a
/// display font, `css` reskins every page via the shared Tailwind/PrimeVue classes the
/// shell and core pages already use, and `js` runs a MutationObserver that keeps
/// relabelling Save/Yes/No as Vue re-renders, matching only exact text inside a
/// .p-button/.p-tag so nothing else on the page is touched. A second item, on
/// shell.topbar, is the escape hatch: a plain link to Portal.Extensions.cls so the
/// theme can always be switched off again.
Class PortalExt.PirateMode.Contribution Extends Portal.Ext.Contribution
{

Parameter ID = "com.banksiaglobal.portal.piratemode";

Parameter NAME = "Pirate mode";

Parameter VERSION = "1.0.0";

Parameter PUBLISHER = "Banksia Global";

Parameter HOMEPAGE = "https://github.com/banksia-global/iris-portal";

Parameter ORDER As INTEGER = 800;

ClassMethod Contribute(slot As %String) As %DynamicArray
{
    return:slot="shell.head" [{
        "id": "piratemode.theme",
        "url": (..FontURL()),
        "css": (..CSS()),
        "js": (..JS())
    }]
    return:slot="shell.topbar" [{
        "id": "piratemode.disable",
        "label": "Disable Pirate Mode",
        "icon": "pi pi-power-off",
        "url": "Portal.Extensions.cls",
        "order": 900
    }]
    return []
}

ClassMethod FontURL() As %String
{
    return "https://fonts.googleapis.com/css2?family=Pirata+One&display=swap"
}

/// Black background, rough (irregular border-radius) panels, parchment text, a pirate
/// headline font. Targets the Tailwind utility classes Portal.Layout and the core pages
/// already render (bg-white/bg-gray-100/border-gray-200/text-gray-*) plus the PrimeVue
/// component classes (.p-card/.p-button/.p-tag/...), so no frontend rebuild is needed.
ClassMethod CSS() As %String
{
    set nl = $char(10)
    set css = ""
    set css = css _ "html, body, #appDiv {" _ nl
    set css = css _ "  background: #0d0b09 !important;" _ nl
    set css = css _ "}" _ nl
    set css = css _ nl
    set css = css _ "body {" _ nl
    set css = css _ "  color: #e8d9b5 !important;" _ nl
    set css = css _ "  font-family: 'Pirata One', 'Papyrus', cursive, serif !important;" _ nl
    set css = css _ "}" _ nl
    set css = css _ nl
    set css = css _ ".bg-white, .bg-gray-50, .bg-gray-100 {" _ nl
    set css = css _ "  background-color: #1a1512 !important;" _ nl
    set css = css _ "  color: #e8d9b5 !important;" _ nl
    set css = css _ "}" _ nl
    set css = css _ nl
    set css = css _ ".border-gray-200, .border-gray-100 {" _ nl
    set css = css _ "  border-color: #5c4326 !important;" _ nl
    set css = css _ "}" _ nl
    set css = css _ nl
    set css = css _ ".text-gray-900, .text-gray-700, .text-gray-500, .text-gray-400 {" _ nl
    set css = css _ "  color: #e8d9b5 !important;" _ nl
    set css = css _ "}" _ nl
    set css = css _ nl
    set css = css _ "a {" _ nl
    set css = css _ "  color: #f2c14e !important;" _ nl
    set css = css _ "}" _ nl
    set css = css _ nl
    set css = css _ "header, aside, footer, .p-card, .p-panel, .p-datatable, .p-overlaypanel, .p-dialog {" _ nl
    set css = css _ "  border-radius: 2px 18px 3px 22px / 16px 3px 20px 2px !important;" _ nl
    set css = css _ "  box-shadow: 3px 3px 0 rgba(0, 0, 0, 0.7) !important;" _ nl
    set css = css _ "  border: 2px solid #5c4326 !important;" _ nl
    set css = css _ "}" _ nl
    set css = css _ nl
    set css = css _ ".p-card, .p-panel, .p-datatable-table, .p-overlaypanel, .p-dialog {" _ nl
    set css = css _ "  background: #1a1512 !important;" _ nl
    set css = css _ "  color: #e8d9b5 !important;" _ nl
    set css = css _ "}" _ nl
    set css = css _ nl
    set css = css _ ".p-button {" _ nl
    set css = css _ "  background: #3b2a14 !important;" _ nl
    set css = css _ "  border: 2px solid #d4a017 !important;" _ nl
    set css = css _ "  color: #f2c14e !important;" _ nl
    set css = css _ "  border-radius: 2px 14px 2px 14px / 14px 2px 14px 2px !important;" _ nl
    set css = css _ "}" _ nl
    set css = css _ nl
    set css = css _ ".p-button:hover {" _ nl
    set css = css _ "  background: #5c4326 !important;" _ nl
    set css = css _ "}" _ nl
    set css = css _ nl
    set css = css _ ".p-tag.p-tag-success {" _ nl
    set css = css _ "  background: #2f6b2f !important;" _ nl
    set css = css _ "  color: #eaffea !important;" _ nl
    set css = css _ "}" _ nl
    set css = css _ nl
    set css = css _ ".p-tag.p-tag-secondary {" _ nl
    set css = css _ "  background: #6b1f1f !important;" _ nl
    set css = css _ "  color: #ffe3e3 !important;" _ nl
    set css = css _ "}" _ nl
    set css = css _ nl
    set css = css _ "::selection {" _ nl
    set css = css _ "  background: #d4a017;" _ nl
    set css = css _ "  color: #1a1512;" _ nl
    set css = css _ "}" _ nl
    return css
}

/// Relabels the core Save button and boolean Yes/No tags without touching anything
/// else: it walks text nodes and only rewrites one whose trimmed value is exactly
/// 'Save' inside a .p-button, or 'Yes'/'No' inside a .p-tag. Idempotent (already-relabelled
/// text no longer matches), so the MutationObserver can safely re-run on every Vue
/// re-render instead of racing the SPA's own updates.
ClassMethod JS() As %String
{
    set nl = $char(10)
    set js = ""
    set js = js _ "(function () {" _ nl
    set js = js _ "  function apply(root) {" _ nl
    set js = js _ "    var walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, null);" _ nl
    set js = js _ "    var node;" _ nl
    set js = js _ "    while ((node = walker.nextNode())) {" _ nl
    set js = js _ "      var text = node.nodeValue.trim();" _ nl
    set js = js _ "      if (!text) continue;" _ nl
    set js = js _ "      var parent = node.parentElement;" _ nl
    set js = js _ "      if (!parent) continue;" _ nl
    set js = js _ "      var tag = parent.closest('.p-tag');" _ nl
    set js = js _ "      var button = parent.closest('.p-button');" _ nl
    set js = js _ "      if (tag && text === 'Yes') {" _ nl
    set js = js _ "        node.nodeValue = node.nodeValue.replace('Yes', 'YARRR!');" _ nl
    set js = js _ "      } else if (tag && text === 'No') {" _ nl
    set js = js _ "        node.nodeValue = node.nodeValue.replace('No', String.fromCodePoint(9760));" _ nl
    set js = js _ "      } else if (button && text === 'Save') {" _ nl
    set js = js _ "        node.nodeValue = node.nodeValue.replace('Save', 'YARRR!');" _ nl
    set js = js _ "      }" _ nl
    set js = js _ "    }" _ nl
    set js = js _ "  }" _ nl
    set js = js _ "  function start() {" _ nl
    set js = js _ "    apply(document.body);" _ nl
    set js = js _ "    new MutationObserver(function () { apply(document.body); })" _ nl
    set js = js _ "      .observe(document.body, { childList: true, subtree: true, characterData: true });" _ nl
    set js = js _ "  }" _ nl
    set js = js _ "  if (document.readyState === 'loading') {" _ nl
    set js = js _ "    document.addEventListener('DOMContentLoaded', start);" _ nl
    set js = js _ "  } else {" _ nl
    set js = js _ "    start();" _ nl
    set js = js _ "  }" _ nl
    set js = js _ "})();" _ nl
    return js
}

}
