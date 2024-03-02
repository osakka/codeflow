<h1>About CodeFlow Application Server</h1>
The CAS server you are currently viewing has been configured with the parameters below.  
Please read the documentation in order to understand in more detail how to better utilize your CAS server, and what to do next.
<br><br>

[[[

  '<pre>';

  'Server reversion                        : TRUNK revision ';
  server.version;
  '<br>';

  'Server webtoken identifier              : '; server.webtokens;        '<br>';
  'Server encoding                         : '; server.encoding;         '<br>';
  'HTTP Request Timeout                    : '; server.httpto;           ' seconds <br>';

  '<br>';

  'Application root directory   [relative] : '; server.appsdir;          '<br>';
  'Log file location            [relative] : '; server.logfile;          '<br>';

  '</pre>';

]]]
