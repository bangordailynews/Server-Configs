#INFINITE LOOPS LOLZ
#Register our local varnish server as a backend, so we can send requests back to ourselves
backend jsonp_varnish { 
	.host = "localhost"; 
	.port = "80"; 
}


#Receive our initial request for a URL with ?jsonp=example
sub vcl_recv {

	# Overwrite the req.url with our JSONP-ESI-TEMPLATE magical code.
	# Put the base URL into X-ESI-Url
	# Put the JSONP callback into X-Callback.
	if (req.url ~ "jsonp=\S") { 
		set req.http.X-Callback = regsub( req.url, ".*[\?&]jsonp=([\.A-Za-z0-9_\[\]]+).*", "\1" ); 
		set req.http.X-ESI-Url = regsub( req.url, "&?jsonp=[\.A-Za-z0-9_\[\]]+", "" ); 

		# Remove a trailing ? 
		set req.http.X-ESI-Url = regsub( req.http.X-ESI-Url, "\?$", "" ); 

		# Fix any accidental ?& 
		set req.http.X-ESI-Url = regsub( req.http.X-ESI-Url, "\?&", "?" );

		# Now we have saved off all the data we need to restore the request on the other side of the JSONP ESI rainbow.
		set req.url = "/JSONP-ESI-TEMPLATE"; 

		#set the backend to varnish and pass the request
		set req.backend = jsonp_varnish; 
		return (pass); # NEVER cache template, since it varies on X-Callback/ESI-Url 
	}
	
}

sub vcl_recv {

	#Processing a JSONP request
	#At the bottom of the config file, we deal with this error code by generating a template with an edge-side include
	if (req.url == "/JSONP-ESI-TEMPLATE") {
		set req.backend = jsonp_varnish;
		error 760;
	}

}

# Custom error to serve up a JSONP template
sub vcl_error {
  if (obj.status == 760) {
    set obj.http.Content-Type = "application/javascript; charset=utf8";
    set obj.http.X-ESI = "1";
    set obj.http.X-JSONP-Server = "1";
    set obj.status = 200;
    set obj.response = "OK";
    synthetic 
      "<esi:include />" + 
      req.http.X-Callback + 
      {"(<esi:include src=""} + req.http.X-ESI-Url + {"" />)"};
	return(deliver);
  }
}

sub vcl_fetch {
	
	# Turn on edge-side includes if we have the ESI header.
	# We turn this on when generating the JSONP wrapper with the ESI above
	if (beresp.http.X-ESI) {
		remove beresp.http.X-ESI;
		set beresp.do_esi = true;
	}

}
