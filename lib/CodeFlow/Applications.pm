################################################################################
#
#  CodeFlow Application Server.
#  Copyright (c) 2009/11 Omar N. Sakka.  All rights reserved.
#
#  Applications Handling Module.
#
#  The use and distribution terms for this software are contained in the file
#  named license.txt, which can be found in the root of this distribution.
#  By using this software in any fashion, you are agreeing to be bound by the
#  terms of this license.
#
#  You must not remove this notice, or any other, from this software.
#  If the license.txt is not found anything to do with using/redistributing
#  this software is prohibited.
#
#  $Author: omar.sakka $
#  $Revision: 273 $
#  $Date: 2011-10-20 10:44:17 +0300 (Thu, 20 Oct 2011) $
#  $HeadURL: http://svn.itdlabs.net:9880/codeflow/trunk/bin/codeflow $
#
################################################################################

################################################################################
# Required Libraries.
################################################################################
use strict;
use warnings;

    $len = 6 if ( !defined($len) );
    $str .= $chars[ rand @chars ] for 1 .. $len;
    return $str;
}

################################################################################
# Override Product Tokens in HTTP::Daemon.
# This is to be able to specify our own custom proction tokens in the web
# server response.
################################################################################
$hdpt->replace(
    'HTTP::Daemon::product_tokens',
    sub {
        if ( defined( $config{http}{web_product_token} ) ) {
            return $config{http}{web_product_token} . '/' . $version;
        }
        else { return $0; }
    }
);

################################################################################
# Rename Running Process.
# If string sent is prefixed with *, then place a spinner at the end.
################################################################################
sub __renproc {
    my ( $str, $msg ) = @_;
    my $cnt = 0;
    my @spinner = ( '|', '/', '-', '\\' );

    # Check the value of String.
    if   ( $str ne '' ) { $str = ' [' . $str . ']'; }
    else                { $str = $0; }

    # Check for message existance.
    # Append a space before the message.
    $msg = '' if ( !defined($msg) );
    $msg = ' ' . $msg;

    # Redefine Process Name.
    if ( defined( $config{process}{name} ) ) {
        if ( $str =~ m/^\s\[(\d)\*(\w+)\]$/ ) {
            $cnt = $1;
            $cnt = 0 if ( $cnt >= 4 );
            $str = ' [' . $2 . ']';
            $str = $str . ' (' . $spinner[$cnt] . ')';
            $cnt++;
        }
        $str = $config{process}{name} . $str;
        $0   = $str . $msg;
    }
    $0 = $str . $msg;
    return $cnt;
}

################################################################################
# Log to Syslog.
################################################################################
sub __slog {
    my ( $str, $lvl ) = @_;

    # Ensure that there is a LogLevel set.
    $config{logging}{SysLogLevel} = 'info'
      if ( !defined( $config{logging}{syslog}{level} ) );
    $lvl = $config{logging}{syslog}{level} if ( !defined($lvl) );

    # Send logging to Syslog.
    if ( defined( $config{logging}{syslog}{enabled} ) ) {
        if ( $config{logging}{syslog}{enabled} ) {
            syslog( "$lvl|$config{logging}{syslog}{facility}", $str );
            return 1;
        }
    }
    return 0;
}

################################################################################
# Remark.
################################################################################
sub __log {
    my ( $str, $lvl ) = @_;
    my ($sub_log_handle);
    my $sub = ( caller(1) )[3];

    # If the sub is defined, mangle it.
    if ( defined($sub) ) {
        $sub =~ s/main:://;
        $sub =~ s/__//g;
        $sub_log_handle = $sub;
        if   ( $sub eq 'ANON' ) { $sub = ''; }
        else                    { $sub = '[' . $sub . '] '; }
    }
    else { $sub = ''; }

    # If the string 'content' is not define, set it to blank.
    $str = '' if ( !defined($str) );

    # If the sub_loh_handle = '', set it to anonymous
    $sub_log_handle = 'anonymous' if ( !defined($sub_log_handle) );

    # Check that the Logging Sub is switched on.
    if (   defined( $config{logging}{subroutine}{$sub_log_handle} )
        || defined( $config{logging}{subroutine}{all} ) )
    {
        if (   $config{logging}{subroutine}{$sub_log_handle}
            || $config{logging}{subroutine}{all} )
        {
            if ( !&__slog( $sub . $str, $lvl ) ) {
                print '[' . $$ . ']' . "\t" . &__tstamp . " > $sub$str\n";
                return 1;
            }
        }
    }

    # Exit Prematurely.
    return 0;
}

################################################################################
# Setup Syslog.
# Remember to call this after your parent fork in order to have the right
# pid displayed.
################################################################################
sub __log_handler {
    my ($name);

    if ( defined( $config{logging}{syslog}{enabled} ) ) {
        if ( $config{logging}{syslog}{enabled} ) {
            if ( defined( $config{process}{name} ) ) {
                $name = $config{process}{name};
            }
            else { $name = 'undef'; }
            $name = $name . '[' . $$ . ']';
            croak 'cannot open syslog'
              if ( !openlog( $name, 'ndelay', 'user' ) );
        }
    }
}

################################################################################
# Output Handler.
# Will keep buffering what is sent to it.
# Send the defined reset command, and reset buffers.
################################################################################
sub __out {
    my ($str) = @_;
    my $sub = ( caller(1) )[3];

    # If the sub is defined, mangle it.
    if ( defined($sub) ) {
        $sub =~ s/main:://;
        $sub =~ s/__//g;
        $sub = '' if ( $sub eq 'ANON' );
    }
    else { $sub = ''; }
    __log 'caller -> [' . $sub . ']';

    # Ensure that the String Contains Something (is defined).
    # Define the Output Buffer if not yet defined.
    $str       = '' if ( !defined($str) );
    $outbuffer = '' if ( !defined($outbuffer) );

    # Reset Command Has Been Sent.
    if ( defined( $config{http}{session}{output_reset} ) ) {
        if ( $str eq $config{http}{session}{output_reset} ) {
            $outbuffer = '';
            $str       = '';
        }
    }

    # Check who is UTF8 Encoded from, and encode content.
    if ( defined( $config{process}{utf8_encode} ) ) {
        foreach ( @{ $config{process}{utf8_encode} } ) {
            if ( $_ eq $sub ) {
                utf8::encode($str);
                __log 'encoded utf8 from [' . $sub . ']';
            }
        }
    }

    # Push more into the end of the buffer.
    $outbuffer .= $str;

    # Return Value of the complete buffer.
    return $outbuffer;
}

################################################################################
# Location Standardization Routine.
# Should be run to standardize locations.
################################################################################
sub __locstd {
    my ($relpath) = @_;
    my ($cwd);

    $relpath = '' if ( !defined($relpath) );
    return $RealBin . $relpath;
}

################################################################################
# Timer.
# Returns time in milliseconds between the start, and stop.
# Start with start, and get reading with stop.
################################################################################
sub __timer {
    my ($t) = @_;

    if   ( defined($t) ) { $t = ( tv_interval $t ) * 1000; }
    else                 { $t = [gettimeofday]; }

    return $t;
}

################################################################################
# Reaper.
# A reaper of dead processes (children).
################################################################################
sub __reaper {
    my ( $stiff, $name, $key );

    while ( ( $stiff = waitpid( -1, &WNOHANG ) ) > 0 ) {

        # Check Who Exactly we are talking about.
        # Need to identify the Caller type for the process.
        foreach $key ( keys %procs ) {
            next if ( $key eq 'count' );
            if ( defined( $procs{$key}{$stiff} ) ) {
                $name = $key;
                last;
            }
        }

        # Ensure that the name has been defined.
        return 0 if ( !defined($name) );

        __log $name
          . ' process ['
          . $stiff
          . '] terminated with status ['
          . $? . ']';

        # Reap a Process.
        if ( defined( $procs{$name}{$stiff} ) ) {
            $procs{count}{$name}--;
            delete $procs{$name}{$stiff}
              if ( defined( $procs{$name}{$stiff} ) );
            __log 'current process count for ' . $name . ' = '
              . $procs{count}{$name};
        }

        # Child Signal Handler (Reinstate)
        $SIG{CHLD} = \&__reaper;

    }
}

################################################################################
# Process(es) Killer.
################################################################################
sub __killer {
    my ($key) = @_;

    if ( defined($key) ) {
        if ( defined( $procs{$key} ) ) {
            __log 'request to kill all processes of type: ' . $key;
            kill 'TERM' => keys %{ $procs{$key} };
        }
    }
    else {
        foreach $key ( keys %procs ) {
            next if ( $key eq 'count' );
            __log 'request to kill all processes of type: ' . $key;
            kill 'TERM' => keys %{ $procs{$key} };
        }
    }
}

################################################################################
# Signal Handler.
# Can Pass Two Special Cases, one is supervisor, and the other is safe.
################################################################################
sub __sig_handler {
    my ($cmd) = @_;
    my ( $sig, $msg );

    # Ensure that the $cmd variable is defined.
    $cmd = 'undef' if ( !defined($cmd) );

    # Logging Information.
    __log 'installing signal handler: ' . $cmd;

    # Handle Die.
    $SIG{__WARN__} = sub {
        __log $cmd . '->signal->warn: ' . join( " ", @_ );

        # Cleanup code for supervisor Termination.
        if ( $cmd eq 'supervisor' ) { &__killer; }
        exit if ( $cmd ne 'safe' );
    };

    # Special Supervisor Signal.
    if ( $cmd eq 'supervisor' ) {
        $SIG{USR1} = sub {
            &__killer('http');
            &__killer('radius');
        };
    }

    # For Non Safe Signals.
    if ( $cmd ne 'safe' ) {
        $SIG{KILL} = $SIG{HUP} = $SIG{TERM} = sub {
            $sig = shift;
            $SIG{$sig} = 'IGNORE';
            __log 'signalled ' . $cmd . ' process - ' . $sig;

            # Cleanup code for supervisor Termination.
            if ( $cmd eq 'supervisor' ) { &__killer; }
            exit;
        };
    }

    # Instate Child Signal Handler for Supervisor.
    if ( $cmd eq 'supervisor' ) { $SIG{CHLD} = \&__reaper; }

    # Install Alarm Signal based on caller.
    # Regardless of caller.  Please be carefull what is added
    # in the configuration file, as things may go wild.
    if ( defined( $config{process}{timeout}{$cmd} ) ) {
        __log 'setting timeout for ' 
          . $cmd . ' to '
          . $config{process}{timeout}{$cmd}
          . ' seconds';
        $SIG{ALRM} = sub {
            __log $cmd
              . '->signal->alarm: timeout '
              . $config{process}{timeout}{$cmd};
            __log $cmd . ' killing process...';
            exit;
        };
    }

    # Clean Return.
    return 1;
}

################################################################################
# Handle Timeouts, this should be specific to a function, and clear command
# should be sent on regular completion.
################################################################################
sub __timeout_handler {
    my ( $caller, $cmd ) = @_;

    if ( defined( $config{process}{timeout}{$caller} ) ) {
        if ( $cmd eq 'start' ) {
            alarm( $config{process}{timeout}{$caller} );
            __log $caller
              . ' timeout = '
              . $config{process}{timeout}{$caller}
              . ' seconds';
        }
        else {
            alarm(-1);
            __log $caller . ' timeout cleared';
        }
    }
    else { __log $caller . 'timeout undefined'; }

    # Clean Return.
    return 1;
}

################################################################################
# Retimestamp.
# This is incase we do not have an expirey set since
# The application possibly timedout.
################################################################################
sub __session_expiry {
    my ( $sid, $app ) = @_;
    my ( $tmp, $tout );

    if ( defined($sid) ) {
        __log 'session id      : ' . $sid;
        $tout = time + $config{http}{session}{timeout};
        if ( defined($app) ) {
            if ( defined( $apps{$app}{http}{session}{timeout} ) ) {
                $tout = time + $apps{$app}{http}{session}{timeout};
            }
        }

        __log 'session timeout : ' . $tout;

        if ( defined( $apps{$app} ) ) {
            __log 'application     : ' . $app;
            $tmp                   = $shmem{$sid};
            $tmp->{$app}->{expire} = $tout;
            $shmem{$sid}           = $tmp;
            return 1;
        }
    }

    __log 'cannot set session expiry.';
    return 0;
}

################################################################################
# IPC Shared Cache.
# Used for sharing data between Inter-Processes.
################################################################################
sub __ipccache {
    my ( $cmd, $sid, $app, $ns, $key, $val ) = @_;
    my ( $r, $tmp, $dbm );

    # Some definitions based on the received variables in order
    # to ascertain where we are with more ease.
    $r = 'local';
    $r = 'global' if !defined($val);
    $r = 'namespace' if !defined($key);
    $r = 'application' if !defined($ns);
    $r = 'session' if !defined($app);

    # Initialize the IPC shared memory hash.
    # And tie it to the shmem hash and file.
    if ( $cmd eq 'initialize' ) {
        if ( defined( $config{http}{session}{file} ) ) {

            # Tie the Hash.
            $dbm = tie(
                %shmem, 'MLDBM::Sync',
                &__locstd( $config{http}{session}{file} ),
                O_CREAT | O_RDWR, 0640
            ) or croak 'cannot setup IPC shared memory';

            # Create a Cache in Memory for faster access.
            if ( defined( $config{http}{session}{mem_cache_size} ) ) {
                $dbm->SyncCacheSize( $config{http}{session}{mem_cache_size} );
            }

            __log 'connected to IPC shared memory';
            return 1;
        }
        else { __log 'http->session->file is not defined'; }
    }

    # Cleanup a specific user session.
    # The only thing we do not cleanup is the globalstash, and expire variables.
    # We do not need any $app defined here, we always traverse all the active
    # applications.
    if ( $cmd eq 'cleanup' ) {
        if ( defined( $shmem{$sid} ) ) {
            foreach $app ( keys %{ $shmem{$sid} } ) {

                # Should simply check if value is not a hash and skip.
                if ( $app eq 'currentapp' || $app eq 'id' ) {
                    __log 'cleanup skipping scalar value : ' . $app;
                    next;
                }

                # Store the expire time.
                if ( defined( $shmem{$sid}{$app}{expire} ) ) {
                    $tmp->{expire} = $shmem{$sid}{$app}{expire};
                }

                # Store the Session Variable Stash.
                if ( defined( $shmem{$sid}{$app}{ $config{stash}{session} } ) )
                {
                    $tmp->{ $config{stash}{session} } =
                      $shmem{$sid}{$app}{ $config{stash}{session} };
                }

                # Delete the Old Session Store.
                # Replace the Session Store and Unlock.
                delete $shmem{$sid}{$app};
                $shmem{$sid}{$app} = $tmp;
            }
            return 1;
        }
    }

    # Store data in the shared memory hash.
    if ( $cmd eq 'store' ) {

        if ( $r eq 'namespace' ) {
            $tmp         = $shmem{$sid};
            $tmp->{$app} = $ns;
            $shmem{$sid} = $tmp;
            __log '(store) ' . $sid . ' -> [' . $r . '] = ' . $app . ':' . $ns;
        }

        elsif ( $r eq 'global' ) {
            $tmp                = $shmem{$sid};
            $tmp->{$app}->{$ns} = $key;
            $shmem{$sid}        = $tmp;
            if ( $ns eq 'timer' ) {
                if ( defined( $config{logging}{debug}{session} ) ) {
                    if ( $config{logging}{debug}{session} ) {
                        __log '(store) ' 
                          . $sid . ' -> [' 
                          . $r . '] = ' 
                          . $app . ':'
                          . $ns . ':'
                          . $key;
                    }
                }
            }
            else {
                __log '(store) ' 
                  . $sid . ' -> [' 
                  . $r . '] = ' 
                  . $app . ':'
                  . $ns . ':'
                  . $key;
            }
        }

        elsif ( $r eq 'local' ) {
            $tmp                        = $shmem{$sid};
            $tmp->{$app}->{$ns}->{$key} = $val;
            $shmem{$sid}                = $tmp;
            __log '(store) ' 
              . $sid . ' -> [' 
              . $r . '] = ' 
              . $app . ':' 
              . $ns . ':'
              . $key . ':'
              . $val;
        }

        else {
            __log $sid . ' : storage call failure.';
        }
        return 1;
    }

   # Delete an Entry, can either be an application, or will check for a complete
   # delete of the session.
    if ( $cmd eq 'delete' ) {
        if ( $r eq 'application' ) {
            if ( defined( $shmem{$sid}{$app} ) ) {
                $tmp = $shmem{$sid};
                delete $tmp->{$app};
                $shmem{$sid} = $tmp;
                __log '(delete) ' . $sid . ' -> [' . $r . '] = ' . $app;
            }
            else {
                __log '(delete) ' . $sid . ' -> [' . $r . '] = ' . $app
                  . ' [invalid]';
            }
        }

        # Check if there are any entries within the session, if none, then
        # we can purge the user session.
        # This is currently a HACK, as we check for two available values right
        # now, one is the currentapp, and the other is the session id.
        if ( defined( $shmem{$sid} ) ) {
            if ( keys %{ $shmem{$sid} } <= 2 ) {
                delete $shmem{$sid};
                __log '(delete) ' . $sid . ' purging session.';
            }
        }

        return 1;
    }

    # Garbage Collector.
    # Loop through the shared memory tied hash, and expire sessions.
    # We also remove invalid sessions, the first loop identifies the
    # sessions that are on the server, the second identifies the application
    # instances.
    if ( $cmd eq 'collector' ) {

        foreach $sid ( keys %shmem ) {
            foreach $app ( keys %{ $shmem{$sid} } ) {

                # Check if there are only scalar values in the current session.
                # In this case, we can remove the entire entry.
                if ( $app eq 'currentapp' || $app eq 'id' ) {

                    #__log 'collector skipping scalar value : ' . $app;
                    next;
                }

                if ( defined( $shmem{$sid}{$app}{expire} ) ) {

                    # This is an expired key.
                    # The session should be purged.
                    if ( $shmem{$sid}{$app}{expire} le time ) {

                        # Print out session specifics if required.
                        if ( defined( $config{logging}{debug}{http}{session} ) )
                        {
                            if ( $config{logging}{debug}{http}{session} ) {
                                __log $app . ' -> ' . $sid . ' [expire]';
                            }
                        }

                        # Delete an Expired Session.
                        &__ipccache( 'delete', $sid, $app );
                    }

              # Create a countdown timer, and tack it onto
              # the user application session.  Good for visual session lifetime.
              # This is an active session.
                    else {
                        &__ipccache( 'store', $sid, $app, 'timer',
                            $shmem{$sid}{$app}{expire} - time );
                    }
                }
                else {

                    # Print out session specifics if required.
                    if ( defined( $config{logging}{debug}{http}{session} ) ) {
                        if ( $config{logging}{debug}{http}{session} ) {
                            __log $app . ' -> ' . $sid . ' [invalid]';
                        }
                    }

                    # Delete an Invalid Session.
                    &__ipccache( 'delete', $sid, $app );
                }
            }
        }

        if ( defined( $config{logging}{debug}{collector} ) ) {
            if ( $config{logging}{debug}{collector} ) {
                __log '-- ipccache collector --';
            }
        }

        # End of Garbage Collection.
        return 1;
    }

    # Default Return on no success.
    # We should never get here really.
    return 0;
}

GGGGGGG

=begin Natural Docs ############################################################
 Function: app_get
   Return Current Application Name.
 Parameters:
   - session id
 Returns:
   current application name.
 See Also:
   ...
=cut ###########################################################################

sub __app_get {
    my ($sid) = @_;
    my ( $tmp, $app );

    # Check the Default Application Name, and use it as default.
    if ( defined( $config{applications}{default} ) ) {
        $app = $config{applications}{default};
    }

    # Check the required session, and check if a currentapp is defined.
    # Even if it is, we need to check if it is a valid application.
    if ( defined($sid) ) {
        __log 'sid : [' . $sid . ']';
        if ($sid) {
            __log 'sid : [' . $sid . '] [!null]';
            if ( defined( $shmem{$sid} ) ) {
                __log 'sid : [' . $sid . '] [valid]';
                if ( defined( $shmem{$sid}{currentapp} ) ) {
                    __log 'sid : [' . $sid . '] [currentapp]';

                    # Check if the application is a valid one.
                    if ( defined( $apps{ $shmem{$sid}{currentapp} } ) ) {
                        $app = $shmem{$sid}{currentapp};
                        __log $sid . ' currentapp is = ' . $app;
                    }
                    else {
                        __log $sid . ' currentapp [' . $app . '] [invalid]';
                    }
                }
            }
        }

        else {
            __log $sid . ' requested currentapp, and not a valid session.';
        }
    }
    else {
        __log 'invalid session requested currentapp.';
    }

    return $app;
}

   - session id
   - application
   - filename  
 Returns:
 See Also:
   ...
=cut ###########################################################################

sub __template_handler {
    my ( $sid, $app, $file ) = @_;
    my ( $tpl, %tmp, $vars, $stash, $error, $key, @keyval, $ca );

    # Install Specific Signal Handler.
    $file = 'undefined' if ( !defined($file) );

    # Create A temporary Copy of the Template Toolkit Variables.
    # We want this since we should not do not want to store
    # mangled paths in the configuration file if we write automagically.
    # This is done for each application.
    %tmp = %{ $apps{$app}{config}{tt2} };

    $tmp{INCLUDE_PATH} =
        &__locstd( $config{applications}{directory} . '/' . $app ) . '.'
      . $config{applications}{extension};
    __log 'current template directory : ' . $tmp{INCLUDE_PATH};

    # We define a compile directory.
    # If a global one is defined, then that is where all the compiles
    # go postfixed with the application name.
    if ( defined( $config{applications}{compile_directory} ) ) {
        $tmp{COMPILE_DIR} =
          &__locstd( $config{applications}{compile_directory} . '/' . $app );
        __log 'compile [global] : ' . $tmp{COMPILE_DIR};
    }
    else {
        if ( defined( $config{tt2}{COMPILE_DIR} ) ) {
            $tmp{COMPILE_DIR} =
              $tmp{INCLUDE_PATH} . '/' . $config{tt2}{COMPILE_DIR};
            __log 'compile [local] : ' . $tmp{COMPILE_DIR};
        }
        else {
            __log 'compile [off]';
        }
    }

    # Render requested Template if available.
    #  OR Render Error Page.
    #  OR Render An Error Message.
    if ( $tpl = Template->new(%tmp) ) {
        if ( -r $tmp{INCLUDE_PATH} . '/' . $file ) {

          # Check if the SID is defined, and if so allow
          # access to the shared memory segment by the template.
          # Place some more variables within the reach of the Templating Engine.
          # Any Variables can be explicitly defined here.
            if ( defined($sid) ) {
                if ( defined( $shmem{$sid}{$app} ) ) {
                    $vars = $shmem{$sid}{$app};
                    $vars->{CLEANUP}    = \&__ipccache( 'cleanup', $sid, $app );
                    $vars->{cwd}        = $tmp{INCLUDE_PATH};
                    $vars->{false}      = JSON::XS::false;
                    $vars->{true}       = JSON::XS::true;
                    $vars->{currentapp} = $app;
                    $vars->{id}         = $shmem{$sid}{id};

            # Add the applications installed hash to the template accessible
            # variables so as to be able to display them.  These are only those
            # defined under the details section of an application configuration.
                    if ( defined( $apps{$app}{config}{stash}{applications} ) ) {
                        $vars->{ $apps{$app}{config}{stash}{applications} } =
                          $apps{details}
                          if ( defined( $apps{details} ) );
                    }

                 # Define the Server Stash, and stash some variables in it.
                 # These are the exported variables as defined in stash->exports
                    if ( defined( $apps{$app}{config}{stash}{server} ) ) {
                        $vars->{ $apps{$app}{config}{stash}{server} }
                          ->{version} = $version;

               # Export the Keys as defined in the stash->exports configuration.
               # These should be in the form <myname>=[TOP]::[VARIABLE]
                        foreach $key (
                            keys %{ $apps{$app}{config}{stash}{exports} } )
                        {

               # Split the exported variable value into the relevant associative
               # array components.
                            @keyval = split /\./,
                              $apps{$app}{config}{stash}{exports}{$key};

             # Since our configuration can only be made up of a minimum of two
             # segments and a maximum of 3, this is the easiest way of exporting
             # the variables, this may be changed in the future.
                            if ( $#keyval == 1 ) {
                                if (
                                    defined(
                                        $apps{$app}{config}{ $keyval[0] }
                                          { $keyval[1] }
                                    )
                                  )
                                {
                                    $vars->{ $apps{$app}{config}{stash}
                                          {server} }->{$key} =
                                      $apps{$app}{config}{ $keyval[0] }
                                      { $keyval[1] };
                                    __log 'exporting variable [' 
                                      . $key . '] = '
                                      . $vars->{ $apps{$app}{config}{stash}
                                          {server} }->{$key};
                                }
                            }

                            # Assumption of 3 values here.
                            elsif ( $#keyval == 2 ) {
                                if (
                                    defined(
                                        $apps{$app}{config}{ $keyval[0] }
                                          { $keyval[1] }{ $keyval[2] }
                                    )
                                  )
                                {
                                    $vars->{ $apps{$app}{config}{stash}
                                          {server} }->{$key} =
                                      $apps{$app}{config}{ $keyval[0] }
                                      { $keyval[1] }{ $keyval[2] };
                                    __log 'exporting variable [' 
                                      . $key . '] = '
                                      . $vars->{ $apps{$app}{config}{stash}
                                          {server} }->{$key};
                                }
                            }

                        # There was an error in the decleration of the variable.
                            else { __log 'error exporting [' . $key . ']'; }
                        }
                    }

                  # Configure the stash->user, and export into the Config Stash.
                  # These are refreshed with each request incase they change.
                  # This may change in the future.
                    if ( defined( $apps{$app}{config}{stash}{configuration} ) )
                    {
                        if ( defined( $apps{$app}{config}{stash}{user} ) ) {
                            $vars->{ $apps{$app}{config}{stash}{configuration} }
                              = $apps{$app}{config}{stash}{user};
                        }
                    }

                }
            }

            # Ensure that any additions are under this line since the session
            # variables will overwrite them otherwise.
            # We define here anything that needs to have the enviroment ready
            # before running.
            $vars->{dbh} = $dbh;

            # Process Template File.
            # Output it to the Receiving End (The Output Handler).
            # We should probably move this somewhere else.
            $tpl->process( $file, $vars, \&__out ) || do {
                $rsp->code(501);
                $rsp->header( 'Content-Type' => 'text/plain' );
                $error = $tpl->error();
                __out "Template Error\n";
                __out "--------------\n";
                __out 'Type : ' . $error->type() . "\n";

             # Show Error Messages.
             # If the TTKit is set tolerant, then the message will always
             # be non descriptive, otherwise, we can see the full error message.
                if ( !defined( $apps{$app}{config}{tt2}{ERROR_HEADER} ) ) {
                    __out 'Info : ' . $error->info() . "\n\n";
                }
                else {

                    # Return a single line of  the error message.
                    if ( $apps{$app}{config}{tt2}{ERROR_HEADER} ) {
                        __out 'Info : '
                          . substr( $error->info(), 0,
                            index( $error->info(), $/ ) )
                          . "\n\n";
                    }
                }

                __out 'Please report this error,' . "\n";
                __out 'stating the complete URI (in the address bar)' . "\n";
                return 0;
            };

            # Variable Re-Stasher.
            # We Take Globally Stashed Variables from Templates, and
            # Store them within the user's session. (Persistant).
            # To Reuse the variable, it is under stash->session, in the
            # TTKit page, it is retreived as global.VARNAME
            if ( defined($sid) ) {
                $stash = $tpl->{SERVICE}->{CONTEXT}->{STASH}->{global};
                foreach ( %{$stash} ) {
                    if ( defined( $stash->{$_} ) ) {
                        &__ipccache( 'store', $sid, $app,
                            $apps{$app}{config}{stash}{session},
                            $_, $stash->{$_} );
                    }
                }

                # Output Variable Dump if defined.
                if ( $apps{$app}{config}{logging}{debug}{http}{session} ) {
                    __log Dumper $shmem{$sid}{$app};
                }
            }

            return 1;
        }
        else { __out 'Error: Template ' . $file . ' not available'; }
    }
    else { __out 'Error: Template Toolkit ' . $tpl->error(); }
    return 0;
}

################################################################################
# Database Handler.
# Connect and disconnect from the main database as specified by the
# configuration file.  This will allow us to open a single database connection
# per process, and not keep opening and closing the connection.  For
# processes that need to connect to alternative databases, this can be done
# from within the specific template.
################################################################################
sub __db_handler {
    my ( $cmd, $sub ) = @_;
    my $dsn;

    # If the default Database is Disabled, Exit.
    if ( defined( $config{DB}{Enabled} ) ) {
        return 1 if ( !$config{DB}{Enabled} );
    }

    # Ensure that a sub name has been passed.
    # Otherwise check if anonymous called is enabled.
    $sub = 'anonymous' if ( !defined($sub) );

    # Database Connect Requested.
    if ( $cmd eq 'connect' ) {

        # Check that the Database Sub is switched on.
        # This will allow us to activate DB handling per process type.
        # We should only allow a connection if it has been defined, and
        # the value is 1.
        if ( defined( $config{DB}{subroutine}{$sub} ) ) {
            return 1 if ( !$config{DB}{subroutine}{$sub} );
        }
        else { return 1; }

        # Check that some of our most important values are defined.
        # without these, we cannot establish a database connection.
        return 0
          if ( !defined( $config{DB}{Driver} )
            || !defined( $config{DB}{Hostname} )
            || !defined( $config{DB}{Port} )
            || !defined( $config{DB}{Database} ) );
        $config{DB}{OPTS} = '' if ( !defined( $config{DB}{OPTS} ) );

        # Define the DSN from the values in the configuration file.
        $dsn = 'DBI:'
          . $config{DB}{Driver}
          . ':database='
          . $config{DB}{Database}
          . ';host='
          . $config{DB}{Hostname}
          . ';port='
          . $config{DB}{Port};
        if (
            $dbh = DBI->connect(
                $dsn,                  $config{DB}{Username},
                $config{DB}{Password}, \%{ $config{DB}{OPTS} }
            )
          )
        {

            # Database connection is successfull.
            __log $sub
              . ' successfull database connection to: '
              . $config{DB}{Database};
            return 1;
        }
        else {

            # Database connection is unsuccessfull.
            __log $sub
              . ' failed database connection to: '
              . $config{DB}{Database};
        }
    }

    # Database disconnection Requested.
    if ( $cmd eq 'disconnect' ) {
        if ($dbh) {
            if ( $dbh->disconnect ) {
                __log ' disconnected from database';
                return 1;
            }
            else {
                __log 'cannot disconnect from database';
            }
        }
    }

    # If reached here, then something went wrong.
    # However we check if we want the process to die, or just carry on
    # if there is a failure to connect to the database.
    if ( defined( $config{DB}{Fatal} ) ) {
        return 1 if ( !$config{DB}{Fatal} );
    }
    return 0;
}

=begin Natural Docs ############################################################
 Function: app_details
   Load Application Details.
 Parameters:
   app - Name of application
 Returns:
   1 always.
 See Also:
   ...
=cut ###########################################################################

sub __app_details {
    my ($app) = @_;

    # Copy the application definition, and make accessible to sessions.
    if ( defined( $apps{$app}{config}{details} ) ) {
        $apps{details}{$app} = $apps{$app}{config}{details};
        __log 'application details : ' . $app . ' [loaded]';
    }
    $apps{details}{$app}{id} = $app;

    return 1;
}

=begin Natural Docs ############################################################
 Function: app_loader
   Application Loader.
   Here we check the pre-requisites for each application, and load them.
 Parameters:
   ap - Path to application
   an - Name of application
   ae - Extension of application
 Returns:
   0 nothing changed
   1 application change detected.
 See Also:
   ...
=cut ###########################################################################

sub __app_loader {
    my ( $ap, $an, $ae ) = @_;
    my ($cf);
    my $reload = 0;

    if ( defined($ap) && defined($an) && defined($ae) ) {

       # Check if a configuration file exists, and load it if required.
       # Remember, we check if the file exists here so as not to croak.
       # If there is no configuration file, then we use the deault configuration
       # for the application.
        $cf = $ap . '/' . $an . '.' . $ae . '/_app.conf';
        if ( -r &__locstd($cf) ) {
            if ( &__config_handler( $cf, $an ) == 2 ) {
                __log 'loading specific config file for : ' . $an;
                &__app_details($an);
                return 1;
            }
        }
        else {
            $reload = 1
              if ( !defined( $apps{$an}{cmtime} )
                || $apps{$an}{cmtime} != $cfg_mtime );

            # Reload the configuration.
            # Update the configuration timestamp.
            if ($reload) {
                $apps{$an}{config} = dclone( \%config );
                $apps{$an}{cmtime} = $cfg_mtime;
                __log $an . ' using default configuration [applied]';
                &__app_details($an);
                return 1;
            }
        }

    }

    # Return 0 here signals that nothing was changes.
    return 0;
}

=begin Natural Docs ############################################################
 Function: apps_handler
   Get Application List.
 Parameters:
   - applications directory
 Returns:
   0 or 1 depending on result success.
 See Also:
   ...
=cut ###########################################################################

sub __apps_handler {
    my ($dir) = @_;
    my ( @a, $d, $t );
    my $reload = 0;

    if ( defined($dir) ) {

        # Check for the existance of the application directory.
        $d = &__locstd($dir);
        if ( -r $d && -d $d ) {

           # Get list of installed applications and push into array.
           # These are clean application names, without extensions or dir paths.
            if ( opendir( DIR, $d ) ) {
                while ( $t = readdir(DIR) ) {
                    push @a, $1
                      if ( $t =~
                        m/^(\w[\w\-]+)\.$config{applications}{extension}$/ );
                }
                closedir(DIR);
            }

            # If no applications are found.
            # This will default to -1 if empty.
            if ( $#a < 0 ) { __log 'no applications installed.'; }

            # Get Application List.
            else {

                # Check if a configuration file exists for each application.
                foreach ( 0 .. $#a ) {
                    $t = $a[$_];
                    $reload =
                      &__app_loader( $dir, $t,
                        $config{applications}{extension} );
                }
            }

            # we should signal the children for a reload.
            if ($reload) {
                __log 'reload requested due to apps changes.';
                kill 'USR1' => $$;
            }
            return 1;

        }
        else {
            __log 'application directory does not exist [' . $dir . ']';
        }
    }
    else {
        __log 'applications directory has not been defined';
    }

    return 0;
}

=begin Natural Docs ############################################################
 Function: resource_handler
   Load Respource File.
 Parameters:
   - session id
   - application
   - filename
 Returns:
   0 or 1 depending on result success.
 See Also:
   ...
=cut ###########################################################################

sub __resource_handler {
    my ( $sid, $app, $file ) = @_;
    my ( $fh, $dir );

    $file = 'undefined' if ( !defined($file) );

    # We set the path according to the passed call.
    $dir =
        $apps{$app}{config}{applications}{directory} . '/' 
      . $app . '.'
      . $apps{$app}{config}{applications}{extension};
    __log 'current resource directory : ' . $dir;

    # Retreive the content, and serve it to the user.
    $file = &__locstd( $dir . '/' . $file );
    if ( open( $fhs{resource}, '<', $file ) ) {
        local $/ = undef;
        binmode( $fhs{resource} );
        $fh = $fhs{resource};
        if ( defined( $config{http}{buffering} ) ) {
            if   ( $config{http}{buffering} ) { __out(<$fh>); }
            else                              { $rsp->content(<$fh>); }
        }
        close( $fhs{resource} );
        return 1;
    }
    else { __out 'Error: Requested Resource Unavailable'; }
    return 0;
}

=begin Natural Docs ############################################################
 Function: mime_handler
   Identify content MIME type.
 Parameters:
   extension of content
 Returns:
   request type: static / dynamic
   content type.
 See Also:
   ...
=cut ###########################################################################

sub __mime_handler {
    my ($ext) = @_;
    my $rt = 'static';    # Request Type (static/dyamic).

    # Check if this is a static or dynamic content.
    # We loop through the array as defined in the configuration file,
    # to see if the specific content type is dynamic or static.
    if ( defined( $config{http}{dynamic_extensions} ) ) {
        foreach ( @{ $config{http}{dynamic_extensions} } ) {
            if ( $_ eq $ext ) {
                $rt = 'dynamic';
                last;
            }
        }
    }

    # If MIME type is unknown, it should be set to default if
    # DEFAULT has been defined.
    $ext = 'undef' if ( !defined( $config{http}{mime}{$ext} ) );

    # Return the Request Type, and the Content Type.
    __log 'extension    : ' . $ext;
    __log 'request type : ' . $rt;
    __log 'content type : ' . $config{http}{mime}{$ext};
    return ( $rt, $config{http}{mime}{$ext} );
}

=begin Natural Docs ############################################################
 Function: config_handler
   Load ini style configuration file.
 Parameters: 
   filename (relative path)
   *application name
 Returns:
   0 or 1 based on the result of the load.
   2 means a reload was requested.
 See Also: 
   ...
=cut ###########################################################################

sub __config_handler {
    my ( $file, $app ) = @_;
    my ( $mtime, $tmp, $c, @t, %a, %b );
    my $reload = 0;

    if ( defined($file) ) {

        $file = &__locstd($file);

        if ( -r $file ) {

            # Get Last Modification Time.
            $mtime = ( stat($file) )[9];

          # Check if Modification Timestamps are the same, otherwise
          # Reload the configuration, we handle the application differntly
          # from the global configuration, we do not need to reload the children
          # if the global modification time is still not set since this request
          # can come from the supervisior itself.
            if ( defined($app) ) {
                if ( defined( $apps{$app}{cmtime} ) ) {
                    return 1 if ( $apps{$app}{cmtime} >= $mtime );
                }
                $reload = 1;
            }
            else {
                if ( defined($cfg_mtime) ) {
                    return 1 if ( $cfg_mtime >= $mtime );
                    $reload = 1;
                }
            }

            # Load Configuration.
            __log "loading file [$file]";

            # Check whether this is an application configuration or global.
            # If not global, we load the values under a special location within
            # the config hash.
            if ( defined($app) ) {
                if ( defined( $apps{$app} ) ) {
                    $tmp = YAML::Tiny->read($file);
                    if ( defined( $tmp->[0] ) ) {
                        %a = %{ $tmp->[0] };

                   # Cleanup the Defines once they are loaded.
                   # This ensures that no application can have variables defined
                   # outside the permissable scope.
                        if ( defined( $config{applications}{definable} ) ) {
                            foreach ( @{ $config{applications}{definable} } ) {
                                $c = $_;
                                @t = split /\./, $c;

                                # One Value.
                                if ( $#t == 0 ) {
                                    if ( defined( $a{ $t[0] } ) ) {
                                        __log $app
                                          . ' -> configuration directive ['
                                          . $c
                                          . '] defined.';
                                        $b{ $t[0] } = $a{ $t[0] };
                                    }
                                }

                                # Two Values.
                                elsif ( $#t == 1 ) {
                                    if ( defined( $a{ $t[0] }{ $t[1] } ) ) {
                                        __log $app
                                          . ' -> configuration directive ['
                                          . $c
                                          . '] defined.';
                                        $b{ $t[0] }{ $t[1] } =
                                          $a{ $t[0] }{ $t[1] };
                                    }
                                }

                                # Three Values.
                                elsif ( $#t == 2 ) {
                                    if (
                                        defined(
                                            $a{ $t[0] }{ $t[1] }{ $t[2] }
                                        )
                                      )
                                    {
                                        __log $app
                                          . ' -> configuration directive ['
                                          . $c
                                          . '] defined.';
                                        $b{ $t[0] }{ $t[1] }{ $t[2] } =
                                          $a{ $t[0] }{ $t[1] }{ $t[2] };
                                    }
                                }

                                # Four Values.
                                elsif ( $#t == 3 ) {
                                    if (
                                        defined(
                                            $a{ $t[0] }{ $t[1] }{ $t[2] }
                                              { $t[3] }
                                        )
                                      )
                                    {
                                        __log $app
                                          . ' -> configuration directive ['
                                          . $c
                                          . '] defined.';
                                        $b{ $t[0] }{ $t[1] }{ $t[2] }{ $t[3] } =
                                          $a{ $t[0] }{ $t[1] }{ $t[3] };
                                    }
                                }

                        # There was an error in the decleration of the variable.
                                else {
                                    __log $app
                                      . ' -> undefinable variable ['
                                      . $c . ']';
                                }
                            }
                        }

                     # We merge the default configuration with the full one now.
                     # This is the complete configuration of the application.
                        %{ $apps{$app}{config} } = %{ merge( \%b, \%config ) };
                        __log "loaded application configuration file [$file]";
                    }
                }
                else {
                    __log 'application [' . $app . '] does not exist';
                }
            }

            # Load global configuration into %config hash.
            else {
                $tmp = YAML::Tiny->read($file);
                if ( defined( $tmp->[0] ) ) {
                    %config = %{ $tmp->[0] };
                    __log "loaded default configuration file [$file]";
                }
            }

            # Stamp Configuation Modification Time.
            if   ( defined($app) ) { $apps{$app}{cmtime} = $mtime; }
            else                   { $cfg_mtime          = $mtime; }

            # Kill Workers for Reload.
            # This is to reflect the new changes.
            if ($reload) {
                __log 'reload requested for workers due to config change.';
                kill 'USR1' => $$;
                return 2;
            }

            # Clean Return.
            # No changes detected.
            return 1;
        }
        else { croak 'configuration file not readable'; }
    }
    else { croak ' configuration file not defined'; }
    return 0;
}

=begin Natural Docs ############################################################
 Function: pidchk
   Process ID Status Checker, and Locker.
 Parameters:
   pid file.
   command - Lock/Unlock/Status
 Returns:
   0 or 1 based on the result of the command.
 See Also:
   ...
=cut ###########################################################################

sub __pidchk {
    my ( $file, $cmd ) = @_;
    my $pid = $$;
    my $fh;

    if ( $cmd eq 'lock' ) {
        if ( !&__pidchk( $file, "status" ) ) {
            if ( open( $fhs{pid}, '>', $file ) ) {
                __log "process [" . $pid . "] started";
                print { $fhs{pid} } "$pid";
                close( $fhs{pid} );
                return 1;
            }
            else { __log 'cannot write process id to ' . $file; }
        }
    }
    elsif ( $cmd eq 'unlock' ) {
        if ( $pid = &__pidchk( $file, "status" ) ) {
            if ( kill 'TERM' => $pid ) {
                if ( open( $fhs{pid}, '>', $file ) ) {
                    __log "process [" . $pid . "] terminated";
                    print { $fhs{pid} } '';
                    close( $fhs{pid} );
                    return 1;
                }
                else { __log "cannot write process id"; }
            }
            else { __log "cannot kill process [" . $pid . "]"; }
        }
    }
    elsif ( $cmd eq 'status' ) {
        if ( defined($file) ) {
            if ( open( $fhs{pid}, '<', $file ) ) {
                $fh = $fhs{pid};
                while (<$fh>) {
                    if ( $_ =~ m/^(\d+)$/ ) {
                        $pid = $1;
                        __log "process [" . $pid . "] in process id file";
                        if ( -e '/proc/' . $pid ) {
                            __log "process [" . $pid . "] running";
                            return $pid;
                        }
                    }
                    else { __log "invalid data in process id file"; }
                }
                close( $fhs{pid} );
            }
            else { __log "error reading process id file"; }
        }
        else { __log "please define process id file"; }
        $pid = 'broken-process-id';
    }
    return 0;
}

=begin Natural Docs ############################################################
 Function: session_handler
   Session Cookie Handler.
 Parameters:
   command - get / set
   unmodified cookie string
 Returns:
   0 for failure
   session id for successfull get
   session id and cookie as a string for successfull set
 See Also:
   ...
=cut ###########################################################################

sub __session_handler {
    my ( $cmd, $ucs ) = @_;
    my ( $key, $cookie, %cookies, $tmp );

    # Get a Cookie if one is found.
    if ( $cmd eq 'get' ) {
        if ( defined($ucs) ) {
            %cookies = parse CGI::Cookie($ucs);

            # Check if Our Specific Cookie is set.
            if ( defined( $cookies{ $config{http}{session}{id} }{value} ) ) {
                $key =
                  join( '',
                    @{ $cookies{ $config{http}{session}{id} }{value} } );

                # Check if key is an active session key.
                if ( defined( $shmem{$key} ) ) {

                    # Stamp the expire time.
                    &__ipccache( 'store', $key, &__app_get($key), 'expire',
                        time + $config{http}{session}{timeout} );

                    # Print out session specifics if required.
                    if ( defined( $config{logging}{debug}{http}{session} ) ) {
                        if ( $config{logging}{debug}{http}{session} ) {
                            __log 'session id: ' . $key . ' [active]';
                        }
                    }

                    # This is a special return.
                    # We return the session id here always.
                    return $key;
                }
                else {
                    __log $key . ' session id [invalid]';
                }
            }
            else {

                # There was a cookie we do not know.
                # We can alert the administrator to it's existance in out logs.
                if ( defined( $config{logging}{debug}{cookie} ) ) {
                    if ( $config{logging}{debug}{cookie} ) {
                        __log 'cookie with invalid name returned';
                    }
                }
            }
        }
    }

    # Set a cookie if one is not found.
    if ( $cmd eq 'set' ) {

        if ( defined( $config{http}{session}{id} ) ) {

            # Generate a Session Key for the User.
            if ( defined( $config{http}{session}{id_length} ) ) {
                $key = &__randstr( $config{http}{session}{id_length} );
            }
            else { $key = &__randstr; }

            # Create the cookie.
            $cookie = CGI::Cookie->new(
                -name     => $config{http}{session}{id},
                -value    => $key,
                -expires  => '+1M',
                -httponly => 1,
                -path     => '/'
            );

            # This is a special return.
            # We always return the Session ID.
            # However we return it as a complete cookie string.
            if ( defined($cookie) ) {

                # Print out session specifics if required.
                if ( defined( $config{logging}{debug}{http}{session} ) ) {
                    __log 'session id: ' . $key . ' [new]'
                      if ( $config{logging}{debug}{http}{session} );
                }

                __log 'session currentapp: ' . $config{applications}{default};
                &__ipccache( 'store', $key, 'currentapp', &__app_get($key) );

                __log 'session id within session reach set.';
                &__ipccache( 'store', $key, 'id', $key );

                return ( $key, $cookie->as_string );
            }
            else {
                __log 'cookie configuration error';
            }
        }
        else { __log 'cookie configuration not found'; }
    }

    # Cookie is Invalid or does not exist, or cannot be set.
    return 0;
}

=begin Natural Docs ############################################################
 Function: housekeeper
   Housekeeping Script Handler.
 Parameters:
   file = $script{current_script}
 Returns:
   0 for failure
 See Also:
   ...
=cut ###########################################################################

sub __housekeeper {

    #my ($file) = @_;
    my $file = $script{current_script};

    # We are not officially a housekeeper.
    __renproc 'housekeeper', 'running: ' . $file;

    # Check the FileName (Script for Housekeeping)
    $file = '' if ( !defined($file) );

    # Timeout for HouseKeepers.
    &timeout_handler( 'housekeeper', 'start' );

    # Cleanup up variable content.
    __out $config{http}{session}{output_reset};

    # Die Signal Disabler.
    if ( defined( $config{housekeeper}{FatalErrors} ) ) {
        &__sig_handler('safe') if ( !$config{housekeeper}{FatalErrors} );
    }

    # Run the Template Handler for the housekeeping file.
    if ( &__template_handler($file) ) {
        if ( defined( $config{housekeeper}{RunLog} ) ) {
            if ( $config{housekeeper}{RunLog} ) {
                &__log( 'housekeeper: [' . $file . '] follows: ', 'debug' );
                &__log( &__out,                                   'debug' );
            }
        }
    }

    # Exit Process.
    # This is the end of the Spawned Process.
    &timeout_handler( 'housekeeper', 'clear' );
    exit;
}

################################################################################
# Parse URI Query String.
# Place key value pairs in special variable location.
# Within the session hash.
################################################################################
sub __querystring {
    my ( $sid, $app, $method, $str ) = @_;
    my ( @in, $key, $value, @tmp );

    # Convert method to lower case, and append an underscore.
    $method = lc($method);

    # Print out some debugging information.
    if ( defined( $config{logging}{debug}{http}{query} ) ) {
        if ( $config{logging}{debug}{http}{query} ) {
            __log 'Session ID: [' . $sid . ']';
            __log 'Method:     [' . $method . ']';
            __log 'String:     [' . $str . ']';
        }
    }

    # Parse the Key Value Pairs.
    if ( defined($str) ) {
        @in = split /&/, $str;
        foreach ( 0 .. $#in ) {
            $in[$_] =~ s/\+/ /g;
            ( $key, $value ) = split /=/, $in[$_], 2;
            $key = '' if ( !defined($key) );
            $key =~ s/%(..)/pack("c",hex($1))/ge;
            $value = '' if ( !defined($value) );
            $value =~ s/%(..)/pack("c",hex($1))/ge;
            $value =~ s/<!--(.|\n)*-->//g;

            # Check if it was a JSON QUERY, this should be handled.
            # We know it's a JSON Query if the Value is '', and the key
            # is { ... }
            # Store Values within the shared memory space.
            # This way we all know what we want, and how to get
            # to it if using templates.
            if ( ( $key =~ qr/^\[?\{(.*)\}\]?$/ ) && ( $value eq '' ) ) {
                @tmp = decode_json($key);
                &__ipccache( 'store', $sid, $app, 'json', @tmp );
                __log Dumper @tmp
                  if ( defined( $config{logging}{debug}{http}{json} ) );
            }
            else {
                if ( $value eq '' ) {
                    __log 'disregarding non KV pair storage request';
                }
                else {
                    &__ipccache( 'store', $sid, $app, $method, $key, $value );
                    __log 'kv pair [' . $key . ' -> ' . $value . ']';
                }
            }
        }
    }

    return 1;
}

################################################################################
# Response Handler.
# Get URL, and URL_TYPE.
# Return Output.
################################################################################
sub __response_handler {
    my ( $sid, $app, $req, $ip, $timer, $gzipencode, $uagent ) = @_;
    my ( $rtype, $rloc, $ctype, $qstr, $fname, $oreq, $gzin, $gzout, $tmp );

    # Stop DIE from Exiting Prematurely.
    &__sig_handler('safe');

    if ( !defined( $apps{$app}{config}{http}{uri_regex} ) ) {
        __log 'config.http.uri_regex is undefined for [' . $app . ']';
        $rsp->code(500);
        return 0;
    }

    # Handle Query Types.
    # Parse the Request into Request Type, Content Type, and Location.
    # Optionally, there may be an application name defined at the
    # beginning of the URL for switching between apps.
    if ( $req =~ qr/^\/($apps{$app}{config}{http}{uri_regex})\.(\w+)$/ ) {
        $rloc  = $1;
        $ctype = $2;

        # Detect Content $ Request Types.
        # We use a temporary variable in order not to damage the $tmp.
        ( $rtype, $tmp ) = &__mime_handler($ctype);
        $rsp->header( 'Content-Type' => $tmp );

  # Search and Replace if Specificed.
  # This is the directory substitution character.
  # If | is the directory_character, then path for /blah/blah will be |blah|blah
        if ( defined( $apps{$app}{config}{http}{directory_substitutor} ) ) {
            $rloc =~ s/$apps{$app}{config}{http}{directory_substitutor}/\//g;
        }

        # Create the filename from the URI (file location), and Type.
        $fname = $rloc . '.' . $ctype;

        # Add the request so that it can be accessed from the request stash
        # variable, this allows us to perform actions on any of the
        # knowns.
        if ( defined( $apps{$app}{config}{stash}{request} ) ) {
            &__ipccache( 'store', $sid, $app,
                $apps{$app}{config}{stash}{request},
                'type', $rtype );
            &__ipccache( 'store', $sid, $app,
                $apps{$app}{config}{stash}{request},
                'content', $ctype );
            &__ipccache( 'store', $sid, $app,
                $apps{$app}{config}{stash}{request},
                'location', $rloc );
            &__ipccache( 'store', $sid, $app,
                $apps{$app}{config}{stash}{request},
                'time', __timer($timer) );
            &__ipccache( 'store', $sid, $app,
                $apps{$app}{config}{stash}{request},
                'agent', $uagent );
        }

        # Handle Content based on Request Type.
        # This will be identified by the MIME handler.
        if ( $rtype eq 'dynamic' ) {
            if ( &__template_handler( $sid, $app, $fname ) ) {
                $rsp->code(200);
            }
            else { $rsp->code(404); }
        }
        else {
            if ( &__resource_handler( $sid, $app, $fname ) ) {
                $rsp->code(200);
            }
            else { $rsp->code(404); }
        }
    }

    # Handle Redirection Queries.
    elsif ( defined( $apps{$app}{config}{http}{redirect}{$req} ) ) {

        # Add the request so that it can be accessed from the request stash
        # We do this here in order to keep a value of the request prior to it
        # being changed by the redirection.
        if ( defined( $apps{$app}{config}{stash}{request} ) ) {
            $tmp = substr( $req, 1 );
            &__ipccache( 'store', $sid, $app,
                $apps{$app}{config}{stash}{request},
                'redirect', $tmp );
        }

       # Handle the response to the user, and set the appropriate response code.
        &__response_handler( $sid, $app,
            '/' . $apps{$app}{config}{http}{redirect}{$req},
            $ip, $timer, $gzipencode, $uagent );
        if ( defined( $apps{$app}{config}{http}{redirect}{code} ) ) {
            $rsp->code( $apps{$app}{config}{http}{redirect}{code} );
        }
        $rtype = 'redirect';
        $rloc  = $req . ' -> ' . $apps{$app}{config}{http}{redirect}{$req};
    }

    # Handle Error.
    else {
        if ( defined( $apps{$app}{config}{http}{redirect}{error_handler} ) ) {
            $oreq = $req;
            &__response_handler( $sid, $app,
                '/' . $apps{$app}{config}{http}{redirect}{error_handler},
                $ip, $timer, $gzipencode, $uagent );
            $rloc  = $req . ' -> ' . $oreq;
            $rtype = 'error';
        }
        else { __out 'Error: invalid request, cannot respond'; }
        $rsp->code(500);
        $rtype = 'error';
        $rloc  = $req;
    }

    # This is equivelant to the Apache Access Log.
    # The format is IP Request_Type *[Content_Type] Content_Location
    # Time_To_Render.
    if ( defined($ctype) ) {
        &__log( "$ip $app $rtype $ctype $rloc " . __timer($timer) . 'ms',
            'info' );
    }
    else {
        &__log( "$ip $app $rtype $rloc " . __timer($timer) . 'ms', 'info' );
    }

    # Replace changed Signals.
    &__sig_handler('http');

    # Return result for all page.
    # Encode if neccesary as GZIP, and return result.
    if ( defined( $apps{$app}{config}{http}{gzip_encoding} ) ) {
        if ( $apps{$app}{config}{http}{gzip_encoding} ) {
            if ($gzipencode) {
                $gzin = __out;
                if ( gzip \$gzin => \$gzout, AutoClose => 1 ) {
                    $rsp->header( 'Content-Encoding' => 'gzip' );
                    return $gzout;
                }
            }
        }
    }

    # Return ungzipped content.
    return __out;
}

################################################################################
# HTTP Communications Handler.
# The main while loop for each HTTP server.
# Keep looping each handler until MaxReq is hit, or the handler exits
# prematurely.
################################################################################
sub __http {
    my $timer;    # Timer for ...
    my $rcnt = 0; # Request Counter.
    my $req;      # Request object.
    my $c;        # Client object.
    my $ip;       # Client IP Address.
    my $qs;       # Query String.
    my $surl;     # Stripped URL.
    my $sid;      # Current Session ID.
    my $app;      # Current Application.
    my $tach;     # Temporary Application Change.
    my $tmp;      # A variable for anything.
    my $gzipencode = 0;     # GZIP Encoding Support.
    my $uagent     = '';    # User Agent.
    my $cookie     = '';    # Cookie Storage.
    my $host       = '';    # Current Host.
    my $xfwd       = '';    # X Forwarded Connection.

    while ( $rcnt <= $config{http}{requests} ) {

        # Reset Explicit Variable.
        $tach = 0;

        # Rename Exception if the requests is 0, that means it's unlimited.
        if ( $config{http}{requests} ) {
            __renproc 'http',
              'serving request ' . $rcnt . '/' . $config{http}{requests};
        }
        else { __renproc 'http', 'serving requests'; }

        # Setup Client Connection.
        if ( $c = $hdo->accept ) {
            $rsp = HTTP::Response->new;
            $c->autoflush(1);

            # Cleanup up variable content.
            __out $config{http}{session}{output_reset};

            # Start Data Collection after accept.
            $timer = __timer;

            # Setup Alarm.
            &__timeout_handler( 'http', 'start' );

            # Get Request.
            # Check on the type of request that has been asked for.
            if ( $req = $c->get_request ) {

                # Dump the contents of the request.
                if ( defined( $config{logging}{debug}{http}{request} ) ) {
                    if ( $config{logging}{debug}{http}{request} ) {
                        __log Dumper $req;
                    }
                }

                # Get Some Connection Specific Credentials.
                $ip = $c->peerhost;

                # Check Request Method.
                #) And act according to the required information exchange.
                if (   $req->method eq 'GET'
                    || $req->method eq 'PUT'
                    || $req->method eq 'POST' )
                {
                    __log 'request method [' . $req->method . '] requested';

                    # Session Handler.
                    if ( defined( $req->as_string ) ) {

                        # Check if a Cookie is defined.
                        # Directly from the Request Header.
                        $cookie = '';
                        if ( defined( $cookie = $req->header('Cookie') ) ) {
                            $cookie = $req->header('Cookie');
                            if (
                                defined(
                                    $config{logging}{debug}{http}{session}
                                )
                              )
                            {
                                if ( $config{logging}{debug}{http}{session} ) {
                                    __log Dumper $cookie;
                                }
                            }
                        }

                        # Get stored cookie value from user browser.
                        # If there is none, then set one.
                        $sid = &__session_handler( 'get', $cookie );
                        if ( !$sid ) {
                            ( $sid, $cookie ) = &__session_handler('set');
                            $rsp->header( 'Set-Cookie' => $cookie );
                        }

                        # Get Current Host Request
                        # We use this to do direct host calls.
                        if ( defined( $host = $req->header('Host') ) ) {
                            $host =~ s/:.*//g;
                            __log 'host request : ' . $host;
                            if ( defined( $config{http}{domain_map}{$host} ) ) {
                                &__ipccache( 'store', $sid, 'currentapp',
                                    $config{http}{domain_map}{$host} );
                            }
                        }

                        # Get Current Application.
                        $app = &__app_get($sid);

                        # We Stamp Current application.
                        &__session_expiry( $sid, $app );

                        # Get User Agent.
                        if ( defined( $uagent = $req->header('User-Agent') ) ) {
                            $uagent = $req->header('User-Agent');
                        }

                        # Check if GZIP Encoding is possible.
                        if (
                            defined(
                                $gzipencode = $req->header('Accept-Encoding')
                            )
                          )
                        {
                            $gzipencode = $req->header('Accept-Encoding');
                            $gzipencode = 1 if ( $gzipencode =~ /gzip/ );
                            __log 'gzip encoding supported';
                        }

                        # Check if GZIP Encoding is possible.
                        if (
                            defined( $xfwd = $req->header('X-Forwarded-For') ) )
                        {
                            $xfwd = $req->header('X-Forwarded-For');
                            __log 'X-Forwarded connection';
                            if (
                                defined( $config{http}{xforward_substitution} )
                              )
                            {
                                $ip = $xfwd;
                            }
                        }

                    }
                    else {
                        __log $ip
                          . ' invalid request method requested "'
                          . $req->method . '"';
                        $rsp->code(300);
                    }
                }
                else {
                    __log $ip
                      . ' invalid request method requested "'
                      . $req->method . '"';
                    $rsp->code(300);
                }

                # Get user supplied data via GET methods.
                # Parse them, and assign them to the session.
                # We strip the additions here \?.* to allow processing
                # (response) to the URL without intervention.
                if ( defined( $req->url ) ) {
                    $surl = $req->url;

                 # Verify if this is an application call.
                 # This should be done here since it is invoked by calling a URL
                 # with some attributes.
                    if ( $surl =~ qr/^(\/.*)?([@\!])(\w+)\??(.*)?$/ ) {
                        $surl = $1;
                        $tach = 1 if ( $2 eq '@' );
                        $tmp  = $3;
                        $qs   = $4;

                        if ( defined( $apps{$tmp} ) ) {
                            $tach = $app if ($tach);
                            $app = $tmp;
                            &__ipccache( 'store', $sid, 'currentapp', $app );

                            if ($tach) {
                                __log 'application call ' . $app
                                  . ' [temporary]';
                            }
                            else {
                                __log 'application call ' . $app;
                            }

                            # We Stamp Current application.
                            &__session_expiry( $sid, $app );
                        }
                    }

                    # No application call, only parameters.
                    elsif ( $surl =~ qr/(.*)\?(.*)/ ) {
                        $surl = $1;
                        $qs   = $2;
                    }

               # Pass the method, and query string to the querystring processor.
                    if ( defined($qs) ) {
                        &__querystring( $sid, $app, $req->method, $qs )
                          if $qs ne '';
                    }

                }

                # Get user supplied data via POST, PUT methods.
                # Parse them, and assign them to the session.
                if ( defined( $req->content ) ) {
                    if ( $req->content ne '' ) {
                        &__querystring( $sid, $app, $req->method,
                            $req->content );
                    }
                }

                # Handle Responses based on Request.
                # Render Output, and send response to client.
                $rsp->content(
                    &__response_handler(
                        $sid,   $app,        $surl, $ip,
                        $timer, $gzipencode, $uagent
                    )
                );

                if ( defined( $config{logging}{debug}{http}{response} ) ) {
                    __log Dumper $rsp
                      if ( $config{logging}{debug}{http}{response} );
                }
                $c->send_response($rsp);

                # Cleaup if session cleanup is required after each call.
                # We DO NOT cleanup the stash.
                if ( defined( $config{http}{session}{cleanup} ) ) {
                    if ( $config{http}{session}{cleanup} ) {
                        if ( defined( $config{logging}{debug}{http}{session} ) )
                        {
                            __log 'cleaning up after session :' . $sid;
                        }
                        &__ipccache( 'cleanup', $sid, $app );
                    }
                }

              # Switch back to original application if it was an temporary call.
              # This will allow easy switching.
                &__ipccache( 'store', $sid, 'currentapp', $tach ) if ($tach);

            }

            else { last; }

            # Setup Alarm.
            &__timeout_handler( 'http', 'clear' );

            $c->close;

        }
        else { last; }
        $rcnt++ unless ( $config{http}{requests} == 0 );

    }

    # End of the worker's lifetime.
    __log 'process [' . $$ . '] terminated after [' . $rcnt . '] request(s)';
    exit;
}

################################################################################
# Process Handler.
# Forks a Process, and installs relevant Signal Handlers.
################################################################################
sub __proc_handler {
    my ( $name, $subref, $max ) = @_;
    my $sigset       = POSIX::SigSet->new(SIGINT);
    my $timer        = __timer;
    my $subref_strip = $subref;
    my $pid;

    # Check the max number of processes that are running at the same time.
    # Do not spawn if max has been reached.
    $max = 1 if !defined($max);
    if ( defined( $procs{count}{$name} ) ) {
        if ( $procs{count}{$name} >= $max ) { return 0; }
        else {
            __log 'Process Throttler : ' . $max;
        }
    }

    # Log some details about the call.
    __log 'Name              : ' . $name;
    __log 'Subroutine        : ' . $subref;
    __log 'Concurrency       : ' . $max;

    if ( sigprocmask( SIG_BLOCK, $sigset ) ) {
        if ( defined( $pid = fork ) ) {

            # If successfull fork.
            if ($pid) {
                $procs{$name}{$pid} = 1;
                $procs{count}{$name}++;
                __log 'Process ID        : ' . $pid;
                __log 'Process Count     : ' . $procs{count}{$name};

                # Process has been forked.
                # Return to the parent process, and leave child to carry on.
                # If we ties successfully to the IPC Cache.
                return 1;
            }

            # Install Signals that are required.
            # Handler to be run.
            &__sig_handler($name);

            # Check that the subref has been defined, and strip for
            # configuration purposes.
            $subref_strip =~ s/__//g;

            #XXX if ( &__db_handler( 'connect', $subref_strip ) ) {

            # Invoke the Subroutine.
            eval {
                no strict 'refs';
                &{$subref};
            };

            # Show time process run for.
            __log $name . ' process completed in ' . __timer($timer) . ' ms';

            # Disconnect from the database.
            # Exit the Process.
            #XXX&__db_handler('disconnect');
            exit(0);

            #XXX}

            # Unsuccessfull Database connection.
            exit(1);
        }
        else { croak $name . ' cannot fork - ' . $!; }
    }
    else { croak $name . 'cannnot block SIGINT for fork - ' . $!; }
}

################################################################################
# HTTP Communications Handler (Process).
################################################################################
sub __http_handler {
    my ($cmd) = @_;

    # Setup the HTTP Daemon Object.
    if ( $cmd eq 'initialize' ) {
        if ( $hdo = HTTP::Daemon->new( %{ $config{http}{daemon} } ) ) {
            __log 'http daemon setup successfully';
            return 1;
        }
        else { __log 'cannot setup http daemon'; }
    }

    # Pre-Fork, and Re-Spawn missing http processes.
    # Return on complete.
    # We disregard the return value here.
    if ( $cmd eq 'fork' ) {
        while (1) {
            return 1
              if (
                !&__proc_handler( 'http', '__http', $config{process}{workers} )
              );
        }
    }

    return 0;
}

################################################################################
# Handle All Housekeeping Requests.
# Run Defined Script(s) For Supervisor if it has been defined.
################################################################################
sub __hkeeper_handler {
    my ( $key, $sc, $dur );

    # Check if Scripts Have Been Disabled.
    if ( defined( $config{housekeeper}{Enabled} ) ) {
        return 1 if ( !$config{housekeeper}{Enabled} );
    }

    # Return if no Scripts Have Been Defined.
    return 1 if ( !defined( $config{housekeeper}{SCRIPTS} ) );

    foreach $key ( sort keys %{ $config{housekeeper}{SCRIPTS} } ) {
        if ( $key =~ m/^(\w+):(@?\d+)$/ ) {
            $sc  = $1;
            $dur = $2;
            if ( $dur =~ m/^@(\d+)$/ ) {
                if ( &__tstamp eq substr( $1, 0, length($1) ) ) {
                    if ( defined( $config{logging}{debug}{hkeeper} ) ) {
                        if ( $config{logging}{debug}{hkeeper} ) {
                            __log 'Script Handle       : ' . $sc;
                            __log 'Invokation Time     : ' . $1;
                            __log 'Running job type [@]: '
                              . $config{housekeeper}{SCRIPTS}{$key};
                        }
                    }

                   # Execute Script.
                   # We Are Temporarily invoking using passing a value to a hash
                   # until we cleanup the proc_handler sub.
                    $script{current_script} =
                      $config{housekeeper}{SCRIPTS}{$key};
                    &__proc_handler( 'housekeeper', '__housekeeper',
                        $config{housekeeper}{MaxHouseKeepers} );
                    return 1;
                }
            }
            else {
                if ( defined( $script{$sc} ) ) {
                    if ( $script{$sc} le time ) {
                        if ( defined( $config{logging}{debug}{hkeeper} ) ) {
                            if ( $config{logging}{debug}{hkeeper} ) {
                                __log 'Invocation          : ' . $script{$sc};
                                __log 'Current Time        : ' . time;
                                __log 'Script Handle       : ' . $sc;
                                __log 'Invokation Time     : ' . $dur;
                                __log 'Running job type [T]: '
                                  . $config{housekeeper}{SCRIPTS}{$key};
                            }
                        }

                 # Delete the Counter, and Execute Script.
                 # We Are Temporarily invoking using passing a value to a hash
                 # until we cleanup the proc_handler sub.
                 #$script{current_script} = $config{housekeeper}{SCRIPTS}{$key};
                 #&__proc_handler( 'housekeeper', '__housekeeper',
                 #                 $config{housekeeper}{MaxHouseKeepers} );
                 #delete $script{$sc};
                        return 1;
                    }
                }

                # Set the Duration Based on the Invocation Time.
                else { $script{$sc} = time + $dur; }
            }
        }
        else {
            __log 'unknown syntax: Script:Handle:@?nnnnn=<script>';
        }
    }

    # Default Return.
    return 0;
}

################################################################################
# Output Redirector.
# Close STDIN, and STDERR, and STDIN.
################################################################################
sub __output_handler {
    my ($cmd) = @_;

    if ( $cmd eq 'start' ) {
        if ( defined( $config{logging}{file} ) ) {
            if (
                open( $fhs{output}, '>>', &__locstd( $config{logging}{file} ) )
              )
            {

                # To avoid errors, just print nothing using the filehandle.
                print { $fhs{output} } '';

                # Redirect OUTPUT to Log File.
                open( STDOUT, '>&', $fhs{output} );
                open( STDERR, '>&', $fhs{output} );
                close(STDIN);
                return 1;
            }
            else { __log 'cannot open log file for writing'; }
        }
        else { __log 'log file not defined'; }
    }
    elsif ( $cmd eq 'stop' ) {
        close( $fhs{output} );
        return 1;
    }
    return 0;
}

=begin Natural Docs ############################################################
 Function: daemon
   Daemon Handler.
 Parameters:
 Returns:
   0 for failure
 See Also:
   ...
=cut ###########################################################################

sub __daemon {
    my ($cmd)  = @_;
    my $sigset = POSIX::SigSet->new(SIGINT);
    my $scnt   = 0;                            # Spinner Counter.
    my ( $pid, $key );

    if ( $cmd eq 'start' ) {
        __log 'starting server daemon';
        if ( sigprocmask( SIG_BLOCK, $sigset ) ) {
            if ( defined( $pid = fork and return 1 ) ) {
                if (setsid) {
                    if (
                        &__pidchk(
                            &__locstd( $config{process}{file} ), 'lock'
                        )
                      )
                    {

                 # Fail if Cannot Initialize HTTP Daemon Handler.
                 # This is only when it is enabled ofcourse.
                 # Note: The HTTP server is an integral part of this application
                 # and so the application should fail if this specific component
                 # cannot be started successfully.
                        return 0 if ( !&__http_handler('initialize') );

                        if ( &__output_handler('start') ) {

                            # Setup Signals we want to catch.
                            &__sig_handler('supervisor');

                            # Setup Syslog Defaults.
                            &__log_handler;

                            # Our Infinite Loop.
                            while (1) {
                                $scnt = __renproc "$scnt*supervisor";

                                # Pre-Fork, and Re-Spawn missing http processes.
                                &__http_handler('fork');

                        # Run HouseKeeper Handler.
                        # This should invoke housekeepers based on duration, and
                        # based on invocation time.
                        #&__hkeeper_handler;

                                # Check if Configuration Needs reloading.
                                &__config_handler($confrel);

                                # Check the Installed Applications List.
                                if (
                                    defined( $config{applications}{directory} )
                                  )
                                {
                                    &__apps_handler(
                                        $config{applications}{directory} );
                                }

                                # Invoke Garbage Collector.
                                &__ipccache('collector');

                     # Sleep 1 second between Cycles.
                     # This is ofcourse mandetory otherwise you will utilize the
                     # CPU 100%.
                                sleep 1;
                                if ( defined( $config{process}{sleep_time} ) ) {
                                    sleep $config{process}{sleep_time};
                                }

                            }

                     # Return 1 as in Successfull End After Infinite While Loop.
                            return 1;

                        }
                    }
                }
                else { croak 'cannot start new session: ' . $!; }
            }
            else { croak 'cannot fork worker: ' . $!; }
        }
        else { croak 'cannot block SIGINT for fork: ' . $!; }
    }

    # If Command given to daemon is stop.
    if ( $cmd eq 'stop' ) {
        if ( !&__pidchk( &__locstd( $config{process}{file} ), 'unlock' ) ) {
            __log 'server daemon not running';
        }
        else { return 1; }
    }
    return 0;
}

=begin Natural Docs ############################################################
 Function: chk_config
   Check that the confiuration variables that are required
   are defined.
 Parameters:
 Returns:
   0 for failure
 See Also:
   ...
=cut ###########################################################################

sub __chk_config {
    my ( @t, $c );

    my @cchk = (
        'process.name',                'http.session.output_reset',
        'process.file',                'http.uri_regex',
        'process.sleep_time',          'applications.extension',
        'stash.session',               'stash.configuration',
        'stash.applications',          'stash.request',
        'stash.server',                'http.session.timeout',
        'http.session.file',           'http.session.id',
        'logging.debug.http.session',  'process.workers',
        'http.requests',               'http.redirect.code',
        'housekeeper.MaxHouseKeepers', 'logging.subroutine.all',
        'applications.directory',      'http.buffering',
    );

    # Traverse through the cchk array, and ensure that all the values have
    # been defined from the previous load, otherwise highlight the missing
    # directive and fail.
    foreach (@cchk) {
        $c = $_;
        @t = split /\./, $c;

        # Two Values.
        if ( $#t == 1 ) {
            if ( !defined( $config{ $t[0] }{ $t[1] } ) ) {
                __log 'configuration directive [' . $c . '] not defined.';
                return 0;
            }
        }

        # Assumption of 3 values here.
        elsif ( $#t == 2 ) {
            if ( !defined( $config{ $t[0] }{ $t[1] }{ $t[2] } ) ) {
                __log 'configuration directive [' . $c . '] not defined.';
                return 0;
            }
        }

        # Assumption of 4 values here.
        elsif ( $#t == 3 ) {
            if ( !defined( $config{ $t[0] }{ $t[1] }{ $t[2] }{ $t[3] } ) ) {
                __log 'configuration directive [' . $c . '] not defined.';
                return 0;
            }
        }

        # There was an error in the decleration of the variable.
        else {
            __log 'internal configuration validation error.';
            return 0;
        }
    }

    __log 'configuration validation passed.';
    return 1;
}

=begin Natural Docs ############################################################
 Function: init
   Initialize The Application.
   System basic initialization of some required variables.  If the initialization
   sub is unsuccessful, then the application should not be started.
 Parameters:
 Returns:
   0 or 1
 See Also:
   ...
=cut ###########################################################################

sub __init {
    my ($bin);

    # We do this for the logging to be enabled prior to the configuration load.
    $config{logging}{subroutine}{all} = 1;

    # Force flush after each write.
    $|++;
    $| = 1;

    # Cleanup Path.
    delete $ENV{PATH} if ( defined( $ENV{PATH} ) );

    # Get Absolute Directory Installation Path.
    $RealBin =~ s/(.*)\/\w+/$1/;
    $RealBin =~ /^(\/[\w\-\s\.\/]+\w+)$/;
    $RealBin = $1;

    # Get Binary Name.
    $bin = $0;
    $bin =~ s/.*\/(.*)$/$1/;

    # Mangle Global Variable Version Number from CVS.
    $version =~ s/\$.*:\s*([\d\.]+)\s*\$/$1/;
    __log $bin . ' TRUNK revision ' . $version;

    # Load Configuration.
    # Setup the SyncDB File for the Sessions.
    # Check if the required fields are defined in the configuration
    # file.
    if ( &__config_handler($confrel) ) {
        if (&__chk_config) {
            if ( &__ipccache('initialize') ) {
                return 1;
            }
        }
    }

    return 0;
}

=begin Natural Docs ############################################################
 Function: MAIN
   This is where the program starts execution of the various components as
   controlled from the command line. The options that are required should be
   added to the $flags scalar, and then invoked under the getopts call.
 Parameters:
 Returns:
 See Also:
=cut ###########################################################################

MAIN: {
    my $flags = "cdtrDM";

    if ( getopts( $flags, \my %flag ) ) {

        # Optional arguments that can be compounded should be listed here.
        # These are switches to turn things on and off, or modify pre runtime
        # values.
        if ( $flag{c} ) { $confrel = $flag{c}; }

        if (&__init) {

            # The Application has already been initialized here.
            # Options that can only be invoked independantly of each other.
            # These should all be elsifs after the first if.
            # The else therefore serves as a reminder.
            if    ( $flag{d} ) { &__daemon('start'); }
            elsif ( $flag{t} ) { &__daemon('stop'); }
            elsif ( $flag{r} ) {
                &__daemon('stop');
                sleep 2;
                &__daemon('start');
            }
            elsif ( $flag{D} ) { print Dumper %config; }
            elsif ( $flag{M} ) { print Dumper %shmem; }
            else { __log 'invocation requires flag(s) [-' . $flags . ']'; }

            # Return Shell OK (0).
            exit 0;

        }
        else { __log 'initialization failed'; }
    }
    else { __log 'getopt failure, check options'; }

    # Return Shell Error (1).
    exit 1;
}
