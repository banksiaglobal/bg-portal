Class Portal.Forbidden Extends Portal.Page
{

Parameter RESOURCE;

Parameter TITLE = "Access denied";

Property username As %String [ InitialExpression = {$username} ];

XData Template [ MimeType = text/vue ]
{
<div class="max-w-xl mx-auto mt-16 text-center">
  <i class="pi pi-lock text-5xl text-gray-400"></i>
  <h1 class="text-2xl font-semibold mt-4">Access denied</h1>
  <p class="text-gray-600 mt-2">{{ username }} does not hold the resource required for this page.</p>
  <a href="Portal.Home.cls" class="inline-block mt-6 text-blue-600 hover:underline">Back to home</a>
</div>
}

}
