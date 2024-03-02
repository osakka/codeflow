################################################################################
#
#  CodeFlow Application Server.
#  Copyright (c) 2009/11 Omar N. Sakka.  All rights reserved.
#
#  Template Toolkit Handler.
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
package CodeFlow::Templating;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(__template_handler);

################################################################################
# Required Libraries.
################################################################################
use strict;
use warnings;
use JSON::XS;
use Data::Dumper;
use Template;
use Template::Plugins;
use Template::Stash::XS;
use Template::Exception;
use Template::Plugin::DBI;
#use Template::Plugin::JSON;
use Template::Plugin::File;
use Template::Plugin::Directory;

=begin Natural Docs ############################################################
 Function: template_handler
   Load Template File.
 Parameters:
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
