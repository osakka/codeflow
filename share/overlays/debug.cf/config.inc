<h1>Current Application Configuration</h1>
The CAS server you are currently viewing has been configured with the parameters below.  
Please read the documentation in order to understand in more detail how to better utilize your CAS server, and what to do next.
<br><br>

[[[
  '<pre>';

  'Current Application                     : '; currentapp;           '<br>';

  '<br>';

  'Template start tags                ^ESC : ';
     FILTER html;
       server.start_tag;
     END;
  '<br>';

  'Template end tags                  ^ESC : ';
     FILTER html;
       server.end_tag;
     END;
  '<br>';

  'Page Render Time                        : '; request.time;              ' milliseconds <br>';

  '<br>';

  'Session ID                      ';
  href ( title = '[clear]' loc = 'reset_session' );
  ' : ';
    
  '<font color="ff3333">';
    id;
  '</font>';
  '<br>';

  'Session timeout time                    : '; server.sessiontimeout;   ' seconds <br>';

  'Session remaining time                  : '; 
  '<div id="timer"></div><br>';

  'Session variable stash identifier       : '; server.sstash;           '<br>';
  'Request variable stash identifier       : '; server.rstash;           '<br>';
  'Configuration variable stash identifier : '; server.cstash;           '<br>';

  '<br>';

  '</pre>';

]]]
