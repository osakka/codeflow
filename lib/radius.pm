################################################################################
#
#  CodeFlow Application Framework Server.
#  Copyright (c) 2009 SiteOps.  All rights reserved.
#
#  Radius Module.
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
#  $Revision: 1.1 $
#  $Date: 2009-12-27 17:06:10 $
#
################################################################################

################################################################################
# Define Package Name.
################################################################################
package codeflow::radius;

################################################################################
# Required Libraries.
################################################################################
use RADIUS::Packet;
use RADIUS::Dictionary;

################################################################################
# Global Variables.
# These are global, and will become part of our global variable stash.
################################################################################

################################################################################
# Radius Communications Handler.
# The main while loop for radius.
# Keep looping each handler until handler exits prematurely.
################################################################################
sub __radius {
  my ($cmd) = @_;
  my ( $soc, $raw, $req, $rsp, $dic );

  # Check if Radius Has been Enabled.
  if ( defined( $config{RADIUS}{Enabled} ) ) {
    if ( !$config{RADIUS}{Enabled} ) { return 1; }
  }
  else {
    __log 'RADIUS::Enabled not defined in configuration file';
    return 0;
  }

  # Rename Running Process.
  __renproc 'radius', 'authentication';

  # Setup the Radius Packet Object.
  if ( defined( $config{RADIUS}{Dictionary} ) ) {
    if ( -r &__locstd( $config{RADIUS}{Dictionary} ) ) {
      $dic =
        RADIUS::Dictionary->new( &__locstd( $config{RADIUS}{Dictionary} ) );
      if ( $soc = IO::Socket::INET->new( %{ $config{RADIUS}{SOCKET} } ) ) {
        while ( $soc->recv( $raw, $config{RADIUS}{MaxMsgLen} ) ) {

          # Read Request packet, and parse as Radius Packet.
          $req = new RADIUS::Packet $dic, $raw;

          # Print some details about the incoming request (try ->dump here)
          if ( defined( $config{RADIUS}{Debug} ) ) {
            if ( $config{RADIUS}{Debug} ) {
              print $req->dump;
            }
          }

          # Check Request, and answer accordingly.
          if ( $req->code eq 'Access-Request' ) {

            __log 'user '
              . $req->attr('User-Name')
              . ' logging in with password '
              . $req->password('test');

            # Create Response Packet.
            $rsp = new RADIUS::Packet $dic;
            $rsp->set_code('Access-Accept');
            $rsp->set_identifier( $req->identifier );
            $rsp->set_authenticator( $req->authenticator );

            # Send Response to Client.
            $soc->send('test');
          }

        }    # End of While.
      }
      else { __log 'could not create bind to socket'; }
    }
    else { __log 'dictionary not found'; }
  }
  else { __log 'dictionary needs to be defined'; }
  return 0;
}

################################################################################
# This is an External Library, we always return true.
################################################################################
1;
