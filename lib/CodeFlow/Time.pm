################################################################################
#
#  CodeFlow Application Server.
#  Copyright (c) 2009/11 Omar N. Sakka.  All rights reserved.
#
#  Time Perl Library.
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
#  $Author: $
#  $Revision: $
#  $Date: $
#  $HeadURL: $
#
################################################################################

################################################################################
# Module Exports.
################################################################################
package CodeFlow::Time;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(__tstamp __timer);

################################################################################
# Required Libraries.
################################################################################
use strict;
use warnings;
use POSIX;
use Time::HiRes qw(gettimeofday tv_interval);

=begin Natural Docs ############################################################
 Function: tstamp
   Time Stamper.
 Parameters:

 Returns:
  Output a stamp (return) with HHMMddmmyy for timestamping the log file.
 See Also:
   ...
=cut ###########################################################################

sub __tstamp { return strftime "%d%m%y@%H%M", localtime; }

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
