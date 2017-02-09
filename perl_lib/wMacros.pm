####################
## wMacros.pm
####################
##
## handle macros
##
###########################################################################
# This code is part of wITIP (a web based Information Theoretic Prover)
#
# Copyright (2017) Laszlo Csirmaz, Central European University, Budapest
# This program is free, open-source software. You may redistribute it
# and/or modify under the terms of the GNU General Public License (GPL).
# There is ABSOLUTELY NO WARRANTY, use at your own risk.
###########################################################################

package wMacros;

use wUtils;
use wParser;
use strict;

#######################################################
=pod

=head1 wITIP perl modules

=head1 wMacros.pm

Parse, add, delete macros

=head2 Data structures

=over 2

=item Macros

A macro is stored as a hash with the following fields:

     std     => 0/1, 1 if standard macro, don't report, don't delete
     argno   => number of arguments, at least 1
     septype => bitmask for separators (separator or pipe)
     name    => 'A' .. 'Z'
     text    => entropy expression; the $i-th argument is (1<<($i-1))
     raw     => the original textual form
     label   => unique label for the macro

=item Errors

Errors (mainly from the parser) are returned as a hash with the
following fields:

    err     => empty string for no error, the error text
    pos     => the position where the error found, can be undef
    aux     => auxiliary error text, can be undef

=back

=head2 Procedures

=over 2

=item $error=wMacros::add_macro($session,$string)

Parse the $string as a macro definition. If there were no errors, 
insert it as a new macro, and add the raw macro text to macro history.
Return an error structure as detailed above.

=back

=cut
#######################################################

sub add_macro {
    my($session,$string)=@_;
    my $parser=new wParser($session);
    my $macro = { };
    $parser->parse_macro_definition($macro,$string);
    # don't process if there was an error
    return { err=> $parser->errmsg(), 
             pos=> $parser->errpos(),
             aux=> $parser->errmsg("aux")
    } if($parser->errmsg());
    # now $macro is the new macro
    my $macros=wUtils::read_user_macros($session);
    my $oldslot=$parser->find_macro($macro);
    return {
       err=> ($macros->[$oldslot]->{std} ? 
              "standard entropy functions cannot be redefined" :
              "this type of a macro is defined (see below); delete it first"),
       pos=> 0,
       aux=> $macros->[$oldslot]->{raw}
    } if( $oldslot >=0);
    # add this macro to history and save
    wUtils::write_user_history($session,"macro",$string);
    $macro->{label} = wUtils::get_label($session);
    push @$macros, $macro;
    wUtils::write_user_macros($session,$macros);
    wUtils::set_modified($session);
    return {err=>""};
}

1;

