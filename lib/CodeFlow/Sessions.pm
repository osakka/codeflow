################################################################################
#
#  CodeFlow Application Server.
#  Copyright (c) 2009/11 Omar N. Sakka.  All rights reserved.
#
#  Session Handling Module.
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
