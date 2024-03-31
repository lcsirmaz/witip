###################
## wDefault.pm
###################
##
## system-wide default values
##
###########################################################################
# This code is part of wITIP (a web based Information Theoretic Prover)
#
# Copyright 2017-2024 Laszlo Csirmaz, UTIA, Prague
# This program is free, open-source software. You may redistribute it
# and/or modify under the terms of the GNU General Public License (GPL).
# There is ABSOLUTELY NO WARRANTY, use at your own risk.
###########################################################################

package wDefault;

use Config;  # perl's own Config module
use strict;

# Configurable global values:
#   BASEDIR:   data directory where permanent data is stored
#   LPSOLVER:  executable program solving LP instances
#   ZIP/UNZIP: program creating/extracting zip archives
#   FILETYPE:  determine file type
#   MKTEMP:    creating a temporary file
#   BASEHTML:  qualified URL, prefix for CSS, JS, IMG
#   BASECGI:   qualified URL where executables are
# Limits
#   MAX_ID_LENGHT: maximal length of a single random variable 
#   HISTSIZE: how many lines to return from the history

use constant {
# limits
    MAX_ID_LENGTH => 20,
    HISTSIZE  => 500,
};

# Extensions for user defined files
#  

########################################################
=pod

=head1 wITIP perl template

=head2 Default.pm

Provide default values, config and macros. This module is generated 
automatically from the template where the following values are
specified and inserted here:

       BASEDIR     fully qualified path where user data is stored
       BASEHTML    fully qualified HTML address of witip pages
       LPSOLVER    the LP helper program
       MKTEMP      program to create temporary files
       ZIP         program to compress files
       UNZIP       program to uncompress zip files
       FILETYPE    determine uploaded file type

=head2 Procedures

=over 2

=item wDefault::setting($session)

Populates $session with global setting, such as data directory,
HTML and CGI base, limits, default extensions, etc.

The maximal number of random variables is limited to 60 for 64-bit perl 
systems (integers have 64 bits), and to 30 for 32-bit perl systems.

=item wDefault::config()

Return the default user configuration for font, style, timeout, etc.

=item wDefault::macros()

Return the array of default macro set: H(a), H(a|b), I(a;b) and I(a;b|c)

=back

=cut

##########################################################

sub setting {
    my($session)=@_;
    # global values
    $session->{setting}->{basedir}  = "@BASEDIR@";
    $session->{setting}->{basehtml} = "@BASEHTML@";
    $session->{setting}->{basecgi}  = "@BASEHTML@/w";
    $session->{setting}->{lpsolver} = "@LPSOLVER@";
    $session->{setting}->{mktemp}   = "@MKTEMP@";
    $session->{setting}->{zip}      = "@ZIP@";
    $session->{setting}->{unzip}    = "@UNZIP@";
    $session->{setting}->{filetype} = "@FILETYPE@";
    $session->{setting}->{histsize} = HISTSIZE;
    # limits
    # max_id_no is 60 for 64 bit systems, and 30 for 32 bit systems
    $session->{setting}->{max_id_no}= 
      ($Config{use64bitint} eq "define" || $Config{longsize}>=8) ? 60 : 30;
    $session->{setting}->{max_id_length}=MAX_ID_LENGTH;
    # extensions
    $session->{setting}->{extconfig}  = ".cfg"; # config file
    $session->{setting}->{extmacro}   = ".mac"; # macros
    $session->{setting}->{exttable}   = ".tbl"; # table of random variable names
    $session->{setting}->{extconstr}  = ".ntr"; # constraints
    $session->{setting}->{extlock}    = ".lck"; # lock
    $session->{setting}->{extlabel}   = ".lbl"; # label
    $session->{setting}->{exthismacro}= ".hma"; # macro history
    $session->{setting}->{exthiscons} = ".hco"; # constraint history
    $session->{setting}->{exthisexpr} = ".hex"; # expression history
    $session->{setting}->{exttemp}    = ".tmp"; # temp files
    $session->{setting}->{extpam}     = ".pam"; # secret value
    # version
    $session->{setting}->{version}    = "2.2";
}

# default config file
sub config { return {
    # appearence
    font       => "monospace, monospace",
    fontsize   => 12,
    tablesize  => 400,   # table size in pixels
    # syntax
    style      => 1,     # 0/1, 0-full, 1-simple
    revIng     => 0,     # 0/1, 0 - no, 1 - yes
    parent     => 0,     # 0/1, 1 for () grouping
    braces     => 1,     # 0/1, 1 for {} grouping
    varprime   => 1,     # 0/1, 1 for prime(s) at the end of variables
    macroarg   => 1,     # 0/1, 1 when all macro aruments must be used
    # simple style syntax
     vardig    => 0,     # 0/1/2, allow allow digit(s) at the end
     var_dig   => 0,     # 0/1/2, allow a_ditig(s) as variables
     sepchar   => ',',   # the varlist separator char
    # others
    timeout    => 5,     # LP timeout in seconds
    title      => "",    # no title
};}

# default set of macros
sub macros {return [
    #H(a) = 1
    {std=>1, argno=>1, septype=>0, name=>"H", raw=>"", label=>-1, text=>{1=>1} },
    # H(a|b) = ab - b
    {std=>1, argno=>2, septype=>1, name=>"H", raw=>"", label=>-2, text=>{2=>-1,3=>1} },
    # I(a,b)=a+b-ab
    {std=>1, argno=>2, septype=>0, name=>"I", raw=>"", label=>-3, text=>{1=>1, 2=>1, 3=>-1} },
    # I(a,b|c)=ac+bc-abc-c
    {std=>1, argno=>3, septype=>2, name=>"I", raw=>"", label=>-4, text=>{5=>1,6=>1,7=>-1,4=>-1} },
];}

1;

