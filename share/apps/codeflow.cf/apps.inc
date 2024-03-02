<h1>Installed Applications</h1>

There are currently [[[ applications.size ]]] applications installed under this CAS instance.<br><br>

 <table border="0" cellpadding="0" cellspacing="0" width="100%"> 

  <thead> 
   <tr> 
    <th>Name</th> 
    <th>Version</th> 
    <th>Description</th> 
    <th>Author</th> 
   </tr> 
  </thead> 

  <tfoot>
   <tr><td colspan="4">Click on an application <b>name</b> to activate.</td></tr>
  </tfoot>

  <tbody> 

[[[

  FOREACH i IN applications.keys.sort;

    # The Application Name.
    IF currentapp.defined;
      IF i == currentapp; '<tr id="current"><td>';
      ELSE; '<tr><td>'; END;
    ELSE; '<tr><td>'; END;
    '<a href="!' _ i _ '">';
    IF applications.$i.name.defined;
      applications.$i.name;
    ELSE;
      i;
    END;
    '</a>';
    '</td>';

    # The Application Version.
    IF applications.$i.version.defined;
      '<td>' _ applications.$i.version _ '</td>';
    ELSE;
      '<td></td>';
    END;

    # The Application Description.
    IF applications.$i.description.defined;
      '<td>' _ applications.$i.description _ '</td>';
    ELSE;
      '<td></td>';
    END;

    # The Application Author.
    IF applications.$i.author.defined;
      '<td>' _ applications.$i.author _ '</td>';
    ELSE;
      '<td></td>';
    END;

    '</tr>';

  END;

]]]

  </tbody> 
 </table> 
