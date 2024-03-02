[[[

  ################################################################################
  # This is only temporarily here.
  ################################################################################
  MACRO statusbutton BLOCK;
    '<div id="statusbutton" class="cfok"></div>';
  END;


  ################################################################################
  # This menubar takes two inputs.
  # location - (for current location identifier.
  # entries  - An associative array for the menu items.
  ################################################################################
  MACRO menubar BLOCK;

    '<div id="menubar">';
    '<ul id="nav">';
      
    FOREACH entry IN entries;

      # Ensure that these entries are always defined within
      # the menu.
      UNLESS entry.defined('name'); entry.name = 'No Name'; END;
      UNLESS entry.defined('location'); entry.location = '#'; END;

      IF entry.defined('submenu');

        # Reset the Temporary Variable.
        active = 0;
        tmp = '';
        FOREACH subentry IN entry.submenu;
          UNLESS subentry.defined('name'); subentry.name = 'No Name'; END;
          UNLESS subentry.defined('location'); subentry.location = '#'; END;

          IF subentry.location == location;
            # Ideintification of the current location.
            # This is based on the submenu item.
            active = 1;
            tmp = tmp _ '<li class="current">';
            tmp = tmp _ '<a href="/' _ subentry.location _ '">' _ subentry.name _ '</a>';
            tmp = tmp _ '</li>';
            # Call the appropriate content handler.
            IF subentry.defined('include'); include = subentry.include; END;
            IF subentry.defined('block'); block = subentry.block; END;
          ELSE;
            tmp = tmp _ '<li>';
            tmp = tmp _ '<a href="/' _ subentry.location _ '">' _ subentry.name _ '</a>';
            tmp = tmp _ '</li>';
          END;

        END;

        # The submenu item.
        IF active;
          '<li class="current">';
            '<a href="'; entry.location; '">'; entry.name; '</a>';
          '<ul>';
        ELSE;
          '<li>';
            '<a href="'; entry.location; '">'; entry.name; '</a>';
          '<ul>';
        END;

        # Output the concatenated variable, and end the submenu.
        tmp;
        '</li>';
        '</ul>';

      # This is a top level menu item.
      # From here on it is easy as can be.
      ELSE;
        IF entry.location == location;
          '<li class="current">';
          '<a href="/'; entry.location; '">'; entry.name; '</a>';
          '</li>';
          # Check whether this is an included file,
          # or a block to run.
          IF entry.defined('include'); include = entry.include; END;
          IF entry.defined('block'); block = entry.block; END;
        ELSE;
          '<li>';
          '<a href="/'; entry.location; '">'; entry.name; '</a>';
          '</li>';
        END;
      END;

    END;

    '</ul>';
    # '<div id="appname">'; 'CodeFlow Application Server'; statusbutton; '</div>';
    '</div>';

    # Run the request according to the content type handler.
    '<div id="content">';
    IF include.defined;
      TRY; INCLUDE $include;
      CATCH; 'The requested resource could not be loaded [include].';
      END;
    ELSIF block.defined;
      TRY; INCLUDE $block;
      CATCH; 'The requested resource could not be loaded [block].';
      END;
    ELSE;
      'The requested resource could not be loaded [undefined].';
    END;
    '</div>';

  END;

]]]
