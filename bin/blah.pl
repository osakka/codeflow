#!/usr/bin/perl -T

use strict;
use warnings;
use diagnostics;

# Make ENV Path Safer.
delete @ENV{ qw(IFS CDPATH ENV BASH_ENV) };

my %config;

use lib '/opt/codeflow/lib';
use CodeFlow::Time;
use CodeFlow::TidBits;
use CodeFlow::Logging;
use CodeFlow::Templating;
use CodeFlow::Sessions;

print "Ok\n";
