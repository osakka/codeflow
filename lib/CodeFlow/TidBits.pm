################################################################################
#
#  CodeFlow Application Server.
#  Copyright (c) 2009/11 Omar N. Sakka.  All rights reserved.
#
#  TidBits Module.
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
# Module Exports.
################################################################################
package CodeFlow::TidBits;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(__randstr __locstd);

################################################################################
# Required Libraries.
################################################################################
use strict;
use warnings;
use FindBin '$RealBin';

=begin Natural Docs ############################################################
 Function: randstr
   Random String Generator.
   Generates a string of length (len) as specificed by the call.  If nothing is
   specified, then the length is 6 by default.
 Parameters:
   input length
 Returns:
  random string
 See Also:
   ...
=cut ###########################################################################

sub __randstr {
    my ($len) = @_;
    my @chars = ( 0, 0 .. 9, 'A' .. 'Z', 'a' .. 'z' );
    my $str = '';

    $len = 6 if ( !defined($len) );
    $str .= $chars[ rand @chars ] for 1 .. $len;
    return $str;
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
