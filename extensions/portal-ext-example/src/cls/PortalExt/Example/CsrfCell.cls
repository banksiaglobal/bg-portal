/// Cell renderer for the example CSRF column: a Tag coloured by the row's CSRFToken flag.
/// The column also has a server-computed value (CsrfColumn), so the plain text is still
/// there for filtering and sorting; the component only changes how the cell looks.
Class PortalExt.Example.CsrfCell Extends Banksia.Bloom.Component
{

Parameter PROPS = "row,col";

XData Template [ MimeType = text/vue ]
{
<Tag :value="row[col.key]" :severity="row.CSRFToken ? 'success' : 'warn'" />
}

}
