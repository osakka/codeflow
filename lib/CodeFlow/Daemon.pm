################################################################################
#
#  CodeFlow Application Server.
#  Copyright (c) 2009/11 Omar N. Sakka.  All rights reserved.
#
#  Daemon Handler Module.
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
use diagnostics;
use POSIX;
use Fcntl qw(:DEFAULT);
use Carp qw(croak);

################################################################################
# Global Variables & Pre-initialization Defines.
# 'confrel' is the only settable variable in this program.
# All other settables should be placed in the configuration file.
# The Path set here is RELATIVE to the root directory not absolute.
################################################################################
my $confrel   = '/etc/codeflow.conf';    # Defaults Configuration File.
my $version   = '$Revision: 273 $';      # Version from CVS.
my $hdpt      = Sub::Override->new;      # Override for Sub Object.
my $outbuffer = '';                      # Output Buffer.
my %procs;                               # Process Tracker.
my %config;                              # Configuration Hash.
my %script;                              # HouseKeeper Script Counters.
my %apps;                                # Application Hash.
my %shmem;                               # Shared Memory Cache.
my %fhs;                                 # File Handlers Hash.
my $cfg_mtime;                           # Configuration Modification Time.
my $hdo;                                 # HTTP Daemon Object
my $rsp;                                 # HTTP Response Object.
my $dbh;                                 # Database Handle (for Apps).

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

