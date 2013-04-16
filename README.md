mod_browserid is a module for Apache 2.0 or later that implements Apache authentication for the BrowserID protocol.

Building and Installing
=======================

```
git clone https://github.com/mozilla/mod_browserid.git (skip this if you are updating)
cd mod_browserid
git pull
make
sudo make install
sudo a2enmod authn_browserid
```

(this assumes apxs is behaving properly on your system; set the APXS_PATH variable to your apxs or apxs2 as appropriate)

Dependencies
============

* apache 2.0 or later
* libcurl 7.10.8 or later
* yajl 2.0 or later
* * sudo apt-get install libyajl2 libyajl-dev


Design Discussion
=================

The module works by intercepting requests bound for protected resources, and checking for the presence of a session cookie.  The name of the cookie is defined in the module's configuration.  Note that while the configuration seems to allow you to set a different cookie name for each protected location, the actual cookie is set for the root of the virtual host, so all Location and Directory directives within a host MUST have the same cookie name.

If the cookie is not found, the user agent is served the ErrorDocument for the directory instead of the resource, with an error code of 401 (which prevents browser caching).  The ErrorDocument must implement the BrowserID sign-in flow, and submit the result to the path identified by the `AuthBrowserIDSubmitPath` directive.  (Note that POST parsing isn't implemented yet; you must use GET!, #5)  The form submission must contain a value named `assertion`, containing the assertion, and another named `returnto`, containing the relative path of the originally requested resource.

The module will intercept requests bound for the SubmitPath, and will verify the BrowserID assertion by submitting it to the server identified in the `AuthBrowserIDVerificationServerURL` directive. (no way to configure SSL trust chain yet #6).  Note that the `ServerName` directive of the server containing the protected directory MUST match the hostname the client uses to perform the login, so the Audience field of the BrowserID assertion checks out.

If the assertion is verified, the module generates a signed cookie containing the user's email address.  The `AuthBrowserIDSecret` directive MUST be used to provide a unique per-server key, or this step is not secure.  All secret values for a host must be identical, since only one cookie is generated.  (Note that there is no expiry #3 on this cookie yet.)  There is currently no option to encrypt the cookie, so the user's email address is visible in plaintext in the cookie; until encryption is implemented (#1), the only privacy-protecting deployment is to use SSL.

Once the session cookie has been established, the "require" directive can be used to specify a single user or a list of users. (could be cool to implement globbing or other ways of identifying a set of valid users, e.g. *@host.com, #8)

The identity thus verified can be passed on to CGI scripts or downstream webservers; the REMOTE_USER environment variable is automatically set to the verified identity, and an HTTP header containing the identity can be set with the `AuthBrowserIDSetSessionHTTPHeader` directive (not implemented yet, #7).

Apache Directives
=================

* `AuthBrowserIDCookieName`:
	Name of cookie to set
* `AuthBrowserIDSubmitPath`:
	Path to which login forms will be submitted.  Form must contain fields named 'assertion' and 'returnto'.
* `AuthBrowserIDVerificationServerURL`:
	URL of the BrowserID verification server.
* `AuthBrowserIDSecret`:
	Server secret for authentication cookie.
* `AuthBrowserIDVerifyLocally`:
	Set to 'yes' to verify assertions locally; ignored if `AuthBrowserIDVerificationServerURL` is set
* `AuthBrowserIDSimulateAuthBasic`:
  Set to 'yes' to attach a synthetic Basic Authorization header to the request containing the username and a placeholder password
* `AuthBrowserIDLogoutPath`:
  Path to which logout requests will be submitted.  An optional 'returnto' parameter in the request will be used for a redirection.

Once authentication is set up, the "require" directive can be used with one of these values:

* `require valid-user`: a valid BrowserID identity must have been presented
* `require user <someID>`: a specific identity must be presented
* `require userfile <path-to-file>`: the BrowserID presented by the user must be the newline-separated list of identities found in this file

NOT YET IMPLEMENTED
-------------------

* `AuthBrowserIDSetHTTPHeader`:
	If set, the name of an HTTP header that will be set on the request after successful authentication.  The header will
  contain &lt;emailaddress&gt;|&lt;signature&gt;, where signature is the SHA-1 hash of the concatenation of the address and
  secret.

* `AuthBrowserIDAuthoritative`:
	Set to 'yes' to allow access control to be passed along to lower modules, set to 'no' by default



Sample Configuration
====================

httpd.conf:

```
  LoadModule mod_auth_browserid_module modules/mod_auth_browserid.so

  # the unprotected login form
  <Directory /var/www/persona_login >
    AuthBrowserIDCookieName myauthcookie
    AuthBrowserIDSubmitPath "/persona_login/submit"
    AuthBrowserIDVerificationServerURL "https://verifier.login.persona.org/verify"
    AuthBrowserIDSecret "MAKE THIS A LONG RANDOM STRING"
  </Directory>

  # where any verified user may go to request additional access to the site
  <Directory /var/www/persona_verified/ >
    AuthType BrowserID
    AuthBrowserIDAuthoritative on
    AuthBrowserIDCookieName auth_id
    AuthBrowserIDVerificationServerURL "https://verifier.login.persona.org/verify"
    AuthBrowserIDSecret "MAKE THIS A LONG RANDOM STRING"

    # must be set (apache mandatory) but not used by the module
    AuthName "My Login"

    # the list of email addresses to allow access for
    require valid-user

    # redirect unauthenticated users to the login page
    ErrorDocument 401 "/persona_login/login.php"

    # where to send unauthorized users
    ErrorDocument 403 /persona_verified/forbidden.php
  </Directory>

  # the protected content directory
  <Directory /var/www/persona_protected_content/ >
    AuthType BrowserID
    AuthBrowserIDAuthoritative on
    AuthBrowserIDCookieName myauthcookie
    AuthBrowserIDVerificationServerURL "https://verifier.login.persona.org/verify"
    AuthBrowserIDSecret "MAKE THIS A LONG RANDOM STRING"

    # must be set (apache mandatory) but not used by the module
    AuthName "My Login"

    # the list of email addresses to allow access for
    require userfile /somewhere/readable-but-not-writeable-by-apache/persona_authorized_user_list

    # redirect unauthenticated users to the login page
    ErrorDocument 401 "/persona_login/login.php"

    # where to send unauthorized users
    ErrorDocument 403 /persona_verified/forbidden.php
  </Directory>
```

/var/www/persona_login/login.php:

```
<?php ?><!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8" />
    <title>Persona sign in demo</title>
</head>
<body style="margin-top:60px">
    <center>
        <p id="signin_button_block"><a id="signin" href=""><img src="/persona_login/email_sign_in_blue.png"></a></p>
        <p id="user_instructions" style="display:none">You must sign in before you can access this site.</p>
    </center>

    <script src="https://login.persona.org/include.js"></script>
    <script>
    function verifyAssertion(assertion) {
        if (assertion !== null) {
            $.ajax({ /* <-- This example uses jQuery, but you can use whatever you'd like */
                type: 'POST',
                url: '/persona_login/submit',
                contentType: 'application/x-www-form-urlencoded',
                data: {
                    assertion: assertion,
                    returnto: '<?php if (isset($_SERVER["REDIRECT_URL"])) echo $_SERVER["REDIRECT_URL"]; else echo "/"; ?>'
                },
                success: function (res, status, xhr) {
                    currentUser = res.email;
                    location.reload();
                },
                error: function (xhr, status, err) {
                    navigator.id.logout();
                }
            });
        }
    }

    var signinLink = document.getElementById('signin');
    var signinLinkClicked = false;
    if (signinLink) {
        signinLink.onclick = function(evt) {
            if (!signinLinkClicked) { // prevent double clicks
                signinLinkClicked = true;
                // Requests a signed identity assertion from the user.
                navigator.id.request({
                    siteLogo: '/persona_login/7373.png',
                    oncancel: function() {
                        $('#user_instructions').show();
                        signinLinkClicked = false
                    }
                });
            }
            return false;
        };
    }

    function signoutUser() {
    }

    var currentUser;
    navigator.id.watch({
        loggedInUser:   currentUser,
        onlogin:        verifyAssertion,
        onlogout:       signoutUser
    });
    </script>
</body>
</html>
```

/somewhere/readable-but-not-writeable-by-apache/persona_authorized_user_list:

```
  user@site.com
  otheruser@site.com
```

example of a log out button:

```
<script>
    function logout() { // make the cookie expire to delete it and logout
        var date = new Date();
        date.setTime(date.getTime()+(-1*24*60*60*1000));
        var expires = "; expires="+date.toGMTString();
        document.cookie = "auth_id="+expires+"; path=/";
        location.reload();
    }
</script>
<button id="signout" onclick="logout();">Logout</button>
```
