Class Portal.Logout Extends Banksia.Bloom.Page
{

ClassMethod OnPreHTTP() As %Boolean
{
    set %session.EndSession = 1
    do %session.Logout()
    set %response.Redirect = "Portal.Home.cls"
    return 1
}

}
