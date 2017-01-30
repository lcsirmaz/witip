####################
## wMakelp.pm
####################
##
## create an LP instance
##
###########################################################################
# This code is part of wITIP (a web based Information Theoretic Prover)
#
# Copyright (2017) Laszlo Csirmaz, Central European University, Budapest
# This program is free, open-source software. You may redistribute it
# and/or modify under the terms of the GNU General Public License (GPL).
# There is ABSOLUTELY NO WARRANTY, use at your own risk.
###########################################################################

package wMakeLP;

use wSession;
use strict;

#########################################################
=pod

=head1 wMakeLP.pm

Create the LP problem from the set of constraints and expression

=head2 Input description

Constraints and the inequality to be checked are stored as a two-element
hash { rel=> <relation>, text=> <expression> }.  Here <relation> is either
"=" (equal to zero), ">=" (greater or equal to zero) or "markov" (for a
Markov chain constraint); <expression> is a hash of { <varset> => <value> }
with neither <varset> nor <value> being zero in case of "=" and ">=", and
is an array of such expressions in case of "markov"; each of them should be
equal to zero.

=head2 How the LP is generated

The LP problem is generated from a set of constraints and the >=0
inequality to be checked. It has the form

    A*x = b

and the LP solver is used to check the feasibility of the problem.

The matrix A is generated as follows. Random variable sets are 
optimized. This means that random variables occuring always together
are grouped and are considered as a single random variable. This
optimization is done by the procedure do_variable_assignment().

Minimal Shannon inequalities H(Vx)+H(Vy) >= H(Vxy)+H(V) are 
generated, where V is a (possibly empty) subset of random variables,
and x, y are single random variables not in V. Furthermore all 
inequalities H(X)>= H(X-x) where X is the set of all random variables
and x runs over all single random variable.

The Shannon inequalities and the constraints give the columns of the
matrix A; the rows are labelled by (non-empty) subsets of the random
variables. LP structural variable x_i is constrained as follows.
If column i corresponds to a Shannon inequality of a constrain >=0,
then x_i>=0. Otherwise, if the constrains is =0, x_i is free.

The right hand side vector b contains the coefficients of the >=0
inequality to be checked. The LP problem has a feasible solution if
and only if this inequality follows from the Shannon inequality and
from the constraints.

When the goal is checking for =0, then two LP instances are run, one
for checking >=0, and the other for cheking <=0 (by negating the vector
b in the LP problem

=head2 LP problem output format

The LP problem is written to a file which has the following format.
First line: 

     P <timeout> <target> <cols> <rows>

where <timeout> is the time limit in seconds for the LP (at least 5);
<target> is 0 for checking >=0, and 1 for checking =0. <cols> and <rows>
are the number of columns and rows in the matrix A. Both columns and
rows are indexed starting from 1 (and not from zero). Next, for each
column a header line

     C <vartype> <entries>

where <vartype> is 0 (for >=0) or 1 (free), and <entries> is the number
of following lines describing the column's content which has the form

     N <rowindex> <value>

Only non-zero values are saved. Finally the non-zero entries in the 
vector b are stored starting with

     C 2 <entries> 

followed by <entries> many N lines as above. The rows and columns are 
shuffled randomly to increase numerical stability of the LP solver.

=head2 Procedures

=over 2

=item $makelp = new MakeLP($session)

Loads some default values from $session

=item $makelp->generate_LP($filename,$goal,$constraints)

write out the LP problem as specified above. $goal is the expression
to be checked, $constraints is a (possibly empty) array of constraints.
Returns zero on success, non-zero on failure: 1: cannot write the file;
2: the specified problem involves less than two random variables.

=back

=cut

#########################################################

sub new {
    my($class,$session)=@_;
    my $self={ 
        max_id_no => $session->getconf("max_id_no"),
        timeout   => $session->getconf("timeout"),
    };
    bless $self, $class;
    return $self;
}

##########################################################
# These procedures make some optimization: collections of 
# random variables which always occur together are replaced
# by a single variable. 
#  {allvars} is a bitmap containing all variables occurring somewhere
#  {var_opt}->[$i] has set bit $i (for the $i-th random variable)
#  and for all other variables which occur together with this random
#  variable.
sub init_var_assignment {
    my($self)=@_;
    my $maxid=$self->{max_id_no}-1;
    $self->{allvars}=0;
    my ($v,$vv)=(0,1);
    for my $i(0 .. $maxid){
        $v|=$vv; $vv<<=1;
    }
    for my $i(0 .. $maxid){
        $self->{var_opt}->[$i]=$v;
    }
}
# get_vars($expr) returns the bitmaks of all variables
# occurring in the expression
sub get_vars {
    my($expr)=@_;
    my $vars=0;
    foreach my $e(keys %$expr){ $vars |= $e; }
    return $vars;
}

# add_var() is called for all variable sets involved. At
# the end, {var_opt}->[$i] has bits set which occur 
# together in all variable sets; bit $i is always set.
sub add_var {
    my($self,$var)=@_;
    $self->{allvars} |= $var;
    my $compvar = (~$var);
    my ($v,$i)=(1,0);
    while($i<$self->{max_id_no}){
        $self->{var_opt}->[$i] &= (($v&$var) ? $var : $compvar);
        $i++; $v<<=1;
    }
}
# this procedure computes the minimal set of variables and assigns
# them to var_tr[]. Computes the final number of rows and columns.
# Return 1 if the final number of variables is less than 2
sub do_variable_assignment {
    my($self)=@_;
    my($maxid,$var_all)=($self->{max_id_no}-1,$self->{allvars});
    for my $i(0 .. $maxid){
        $self->{var_tr}->[$i]=0; # nothing is assigned yet
        $self->{var_opt}->[$i] &= $var_all; # keep only used vars
    }
    my($nextv,$varno)=(1,0);
    for my $i(0 .. $maxid){
        next if(!($var_all&(1<<$i))); # not used
        next if($self->{var_tr}->[$i]); # value assigned
        my $voi=$self->{var_opt}->[$i];
        for my $j ($i .. $maxid){
            $self->{var_tr}->[$j]=$nextv
               if(($voi>>$j)&1);
        }
        $nextv<<=1; $varno++;
    }
    return 1 if($nextv < 2 );
    $self->{rows}= $nextv-1;
    $self->{shannon} = $varno<2 ? 0 :$varno<3 ? 1
       : $varno*($varno-1)*(1<<($varno-3));
    $self->{cols} = $self->{shannon} + $varno;
    $self->{varno} = $varno;
    return 0;
}
# get the translated variable
sub varidx {
    my($self,$idx)=@_;
    my($w,$i)=(0,0);
    while($idx){
        $w |= $self->{var_tr}->[$i] if($idx & 1);
        $i++; $idx>>=1; 
    }
    return $self->{rowperm}->[$w];
}

############################################################
# permute rows and columns in the LP problem randomly.
# make a random permutation of $arr[1..$len]
sub perm_array {
    my($len,$arr)=@_;
    for my $i(1 .. $len){
        my $j=$i+int(($len-$i)*rand());
        my $t=$arr->[$i]; 
        $arr->[$i]=$arr->[$j]; $arr->[$j]=$t;
    }
}
sub permute_cols_and_rows { # number of constraints
    my($self,$constr)=@_;
    # increase cols by the number of constraints ...
    $self->{cols}+=$constr;
    $self->{rowperm}=[]; $self->{colperm}=[];
    for my $i(0 .. $self->{rows}){
        $self->{rowperm}->[$i]=$i;
    }
    perm_array($self->{rows},$self->{rowperm});
    for my $i(0 .. $self->{cols}){
        $self->{colperm}->[$i]=$i-1;
    }
    perm_array($self->{cols},$self->{colperm});
}
############################################################
sub print_column {
    my($flp,$type,$col)=@_;
    print $flp "C $type ",scalar @$col,"\n";
    foreach my $item (sort {$a->[0]<=>$b->[0]} @$col ){
       print $flp "N ",$item->[0]," ",$item->[1],"\n";
    }
}
# add the Shannon inequality I($v1,$v2|$v3) >=0 as the next column
sub add_shannon {
    my($self,$flp,$idx)=@_;
    $idx < $self->{shannon} || die "wrong index in shannon\n";
    my $varno=$self->{varno};
    my $v2=$idx >> ($varno-2);
    my $v1=0; while($v2>$v1){ $v1++; $v2-=$v1; } $v1++;
    $v2 < $v1 || die "impossible\n";
    
    $v1=1<<$v1; $v2=1<<$v2;
    my $v3 = $idx & (-1 + (1<<($varno-2)));
    my $mask = -1+$v2; $v3 = ($v3&$mask) | (($v3& ~$mask)<<1);
       $mask = -1+$v1; $v3 = ($v3&$mask) | (($v3& ~$mask)<<1);
    if($v3){
        print_column($flp,0,[
            [$self->{rowperm}->[$v1|$v3],1],
            [$self->{rowperm}->[$v2|$v3],1],
            [$self->{rowperm}->[$v3],-1],
            [$self->{rowperm}->[$v1|$v2|$v3],-1]
        ]);
    } else {
        print_column($flp,0,[
            [$self->{rowperm}->[$v1|$v3],1],
            [$self->{rowperm}->[$v2|$v3],1],
            [$self->{rowperm}->[$v1|$v2|$v3],-1]
        ]);
    }
}
# add the Shannon inequality H($v2|$v1)>=0
sub add_shannon2 {
    my($self,$flp,$idx)=@_;
    my $varno=$self->{varno};
    $idx < $varno || die "wrong index in shannon2\n";
    my $v1=(1<<$varno)-1;
    my $v2= $v1 & ~(1<<$idx);
    print_column($flp,0,[
       [$self->{rowperm}->[$v2],-1],
       [$self->{rowperm}->[$v1],1]
    ]);
}
# add the constraint $constr as the next column
sub add_constraint {
    my($self,$flp,$type,$constr)=@_;
    my @arr=();
    foreach my $v (keys %$constr){
       push @arr, [$self->varidx($v),$constr->{$v}];
    }
    print_column($flp,$type,\@arr);
}

sub generate_LP {
    my($self,$filename,$goal,$constraints)=@_;
    my @const=(); my @type=();
    # collect all constraints
    foreach my $c (@$constraints) {
        next if($c->{skip}); # disabled
        if($c->{rel} eq "="){
            push @const, $c->{text};
            push @type, 1;
        } elsif($c->{rel} eq ">="){
            push @const, $c->{text};
            push @type, 0;
        } elsif($c->{rel} eq "markov"){
            foreach my $e(@{$c->{text}}){
                push @const, $e;
                push @type, 1;
            }
        } else {
            die "unknown constraint type\n";
        }
    }
    my $constno = scalar @const; # number of constraints
    # use constraints which have common random variable with the goal
    # actually, we could do better: if the two sets have only one
    # element in common, they can always be amalgamated (and give no
    # new condition on either one).
    if($constno>0){
        my $goalvars=get_vars($goal->{text});
        my @cvars=();
        for my $e(@const){ push @cvars,get_vars($e); }
        my $added=1;
        while($added){
            $added=0;
            foreach my $v(@cvars){
                next if(($v&$goalvars)==0);
                if($goalvars!=($goalvars|$v)){
                    $added=1;
                    $goalvars |= $v;
                }
            }
        }
        foreach my $v(@cvars){
           $added=1 if(($v&$goalvars)==0);
        }
        if($added){ # some constraints can be thrown away
            my @newconst=(); my @newtype=();
            for my $i(0..$constno-1){
               if($cvars[$i]&$goalvars){
                  push @newconst,$const[$i];
                  push @newtype, $type[$i];
               }
            }
            @const=(@newconst); @type=(@newtype);
            $constno = scalar @const;
        }
    }
    # collect all variables
    $self->init_var_assignment();
    # add all variable sets, first those in $goal
    foreach my $e (keys %{$goal->{text}}){
        $self->add_var($e);
    }
    # then those in constraints
    foreach my $c (@const){ 
      foreach my $e (keys %$c){
         $self->add_var($e);
      }
    }
    # not enough random variables are left
    return 2 if($self->do_variable_assignment());
    $self->permute_cols_and_rows($constno);
    open(my $lpf,">",$filename) || return 1;
      print $lpf "P",
         " ",$self->{timeout},   # timeout
         " ",($goal->{rel} eq "=" ? 1 : 0),  # direction
         " ",$self->{cols},      # columns
         " ",$self->{rows},      # rows
         "\n";
      # go over all columns in a random order
      for my $i(1 .. $self->{cols}){
          my $reali = $self->{colperm}->[$i];
          if($reali < $self->{shannon} ){
              $self->add_shannon($lpf,$reali);
          } else {
              $reali -= $self->{shannon};
              if($reali < $self->{varno}){
                  $self->add_shannon2($lpf,$reali);
              } else {
                  $reali -= $self->{varno};
                  $reali < $constno || die "index wrong when doing constraint\n";
                  $self->add_constraint($lpf,$type[$reali],$const[$reali]);
              }
          }
      }
      # print out the goal
      $self->add_constraint($lpf,2,$goal->{text});
    close($lpf);
    return 0;
}


1;

