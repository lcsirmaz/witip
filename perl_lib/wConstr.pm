####################
## wConstr.pm
####################
##
## handle constraints
##
###########################################################################
# This code is part of wITIP (a web based Information Theoretic Prover)
#
# Copyright (2017) Laszlo Csirmaz, Central European University, Budapest
# This program is free, open-source software. You may redistribute it
# and/or modify under the terms of the GNU General Public License (GPL).
# There is ABSOLUTELY NO WARRANTY, use at your own risk.
###########################################################################

package wConstr;
use wUtils;
use strict;

############################################################
=pod

=head1 wITIP perl modules

=head2 wConstr.pm

Parse, add, and delete constraints

=head2 The constraint and error structure

=over 2

=item Constraint

A constraint is a hash with the following fields:

     rel   => "=", ">=", "markov"
     text  => entropy expression or an array of expressions for markov
     skip  => 0/1, 1 when the constraint is disabled
     raw   => the original textual form
     label => unique integer to identify the constraint

When rel is "markov", the text field is an array of expressions, all =0; 
otherwise it is the entropy expression which must be =0 or >=0,

=item Errors

Errors (mainly from the parser) are returned as a hash with the
following fields:

    err     => empty string for no error, the error text otherwise
    pos     => the position where the error found, can be undef
    aux     => auxiliary error text, can be undef

=back

=head2 Procedures

=over 2

=item wConstr::add_constraint($session,$text)

Parse the constraint given in $text. If there were no errors,
insert it as the last constraint; add the raw text to the constraint
history. Returns an error structure as detailed above.

=item $id_table = wConstr::adjust_id_table($id_table,$constraints)

Deletes entries in the given id table which are not used by any of the
constraints.  Used when adding or deleting a constraint.  The $id_table
contains random variable names from the disabled constraints as well. 
This is necessary as the original form of the constraint cannot be 
re-parsed when enabling it again: some of the macros could have been
redefined or deleted.

=back

=cut
############################################################

# clear slots in $id_table which do not occur in any of the
# constraints. Clobbers $id_table.
sub adjust_id_table {
    my($id_table,$constr)=@_;
    my $v=0;
    foreach my $c(@$constr){
        if($c->{rel} eq "markov"){
           foreach my $e(@{$c->{text}}){
               foreach my $k (keys %$e){
                  $v |= $k;
               }
           }
        } else {
           foreach my $k (keys %{$c->{text}}){
              $v |= $k;
           }
        }
    }
    # clear slots where $v has zero
    my $idx=0;
    while($v){
       $id_table->[$idx]="" if(!($v&1));
       $idx++; $v>>=1;
    }
    return $id_table;
}

sub add_constraint {
    my($session,$string)=@_;
    my $constr=wUtils::read_user_constraints($session);
    # check if the same constraint is there verbatim
    # after parsing one can check whether the constraint is 
    # really a new one  -- not done
    $string =~ s/^\s*//; $string=~ s/\s*$//;
    return { err=>"no constraint was given",
    } if($string =~ /^$/) ;
    foreach my $c (@$constr){
        return { err=> "this constrain is there, no need to add it again",
        } if($string eq $c->{raw});
    }
    use wParser;
    my $parser=new wParser($session);
    my $c={skip => 0}; # visible
    $parser->parse_constraint($c,$string);
    return { err=>$parser->errmsg(), 
             pos=>$parser->errpos(),
             aux=>$parser->errmsg("aux")
    } if($parser->errmsg());
    # add to the constraint history and save
    wUtils::write_user_history($session,"cons",$string);
    $c->{label} = wUtils::get_label($session);
    $c->{skip} = 0;
    push @$constr, $c;
    wUtils::write_user_constraints($session,$constr);
    my $id_table=adjust_id_table($parser->get_id_table(),$constr);
    wUtils::write_user_id_table($session,$id_table);
    wUtils::set_modified($session);
    return { err=>""};
}

1;



