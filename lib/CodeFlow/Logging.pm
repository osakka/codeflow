################################################################################
#
#  CodeFlow Application Server.
#  Copyright (c) 2009/11 Omar N. Sakka.  All rights reserved.
#
#  Logging Perl Library.
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
package CodeFlow::Logging;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(__slog __log __log_handler);

################################################################################
# Required Libraries.
################################################################################
use strict;
use warnings;
use File::Find;
use Sys::Syslog;
use Carp qw(croak);

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
    my ( $sub_log_handle );
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
    my ( $name );

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
