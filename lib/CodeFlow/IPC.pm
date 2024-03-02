################################################################################
#
#  CodeFlow Application Server.
#  Copyright (c) 2009/11 Omar N. Sakka.  All rights reserved.
#
#  Inter-Process Communication Facility Module.
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
use MLDBM::Sync;
use MLDBM qw(DB_File Storable);
use MLDBM qw(MLDBM::Sync::SDBM_File);

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
