####################
## wParser.pm
####################
##
## parse an entropy expression
##
###########################################################################
# This code is part of wITIP (a web based Information Theoretic Prover)
#
# Copyright (2017) Laszlo Csirmaz, Central European University, Budapest
# This program is free, open-source software. You may redistribute it
# and/or modify under the terms of the GNU General Public License (GPL).
# There is ABSOLUTELY NO WARRANTY, use at your own risk.
###########################################################################

package wParser;

use wUtils; # EPS, read_user_macros()
use strict;
use constant { EPS => wUtils::EPS };

#######################################################
=pod

=head1 wITIP perl modules

=head2 wParser.pm

General routines to parse macro definitions, constraints, queries.

=head2 Data structures

=over 2

=item Random variable representation

Random variables are represented as bits from 1..MAX_ID_NO; and a
variable list as bitmaps: bit $i is set if variable $i is in that 
list.

=item Entropy expression

An entropy expression is a hash of { I<varlist> => I<coeff>} pairs; 
I<varlist> is an integer representing the variable list, and I<coeff> is 
the corresponding coefficient. Neither value is zero.

=item Macro

A macro is a hash of the following fields

     std     => 0/1  (1 if standard macro, don't report, don't delete)
     argno   => number of arguments, at least one
     septype => bitmask for separators (separator or pipe character)
     name    => 'A' .. 'Z'
     text    => entropy expression; the $i-th argument is (1<<($i-1))
     raw     => the original textual form
     label   => a unique number identifying the macro

=item Constraint

A constraint is a hash with the following fields:

     rel     => "=", ">=", "markov", "common"
     text    => entropy expression or an array of expressions
     skip    => 0/1 (1 when the constraint is disabled)
     raw     => the original textual form
     label   => a unique number identifying the macro

when I<rel> is "markov" or "common", I<text> is an array of expressions,
all =0; otherwise I<text> is the entropy expression. 

=item Identifier table

Random variable names used in constraints are stored in the identifier
table.  This table can store at most `max_id_no' entries (variable lists
are handled as bitmasks, this number is either 30 or 60 depending on the
machine architecture).  The table is an array [0 ..  max_id_no-1] where the
i-th entry contains the string of the i+1-st variable, or "" or undef if
that slot is free.  The id table is loaded and used when parsing a
query with constraints, or when a new constraint is added.  It can start
empty when checking without constraints, or when adding a new macro.  The id
table must be adjusted when a constrain is deleted, or when a new
constrain is added.

=back

=head2 Procedures

=over 2

=item $parser = new wParser($session)

Loads the default values and user macro definitions

=item $parser->parse_relation($result,$string,$standalone)

Parses the given $string as a relation. When $standalone is set, the relation
is to be checked without constraints, so the id table is not loaded. On success
the following fields of the hash $result are filled:

    $result->{rel} = the relation of the query, one of "=" ">=" or "=?"
    $result->{text}= the expression

When the relation is ">=" the expression should be checked
for >=0; if the relation is "=" then it should be checked for ==0; for
relation "=?" $parser->print_expression($result->{text}) gives the
unrolled result to be printed out.

Call $parser->errmsg() to find whether there was any error.

=item $parser->parse_constraint($result,$string)

Parses the given $string as a constraint. On success the following 
fields of the hash $result are filled:

    $result->{rel}  = one of "markov", "common", "=", ">="
    $result->{text} = the unrolled constraint depending on "rel"
    $result->{raw}  = the original string

When I<rel> is "=" (check for ==0) or ">=" (check for >=0) then I<text>
is an expression.  When I<rel> is "markov" or "common", then I<text> is
an array of expressions, all of which must be ==0. To recover the new 
id table, use $parser->get_id_table(); to find out whether there was 
an error call $parser->errmsg().

=item $parser->parse_macro_definition($macro,$string)

Parses the macro definition given in $string. On success sets the 
following fields in the $macro hash:

    $macro->{name}    = the macro name
    $macro->{argno}   = number of arguments
    $macro->{septype} = argument separator bitmask
    $macro->{std}     = 0
    $macro->{text}    = the expanded macro text
    $macro->{raw}     = the original string

These fields are set properly only when there were no errors.

=back

=head2 Auxiliary procedures

=over 2

=item $parser->errmsg($aux)

Without argument returns the error string, which is "" if there were no
errors. When $aux is defined, the auxiliary error output is returned;
valid only when there was an error message. Typically the unrolled form of
the relation when complaining about its triviality.

=item $parser->errpos()

Returns the error position; valid only when errmsg() returns a non-empty
string.

=item $parser->print_expression($expr)

The input is an expression hash, the returned value is the unrolled 
string representation using the most recent variable table and style.

=item $parser->find_macro($macrohead)

Returns the index of the macro with the corresponding name, argno,
and septype, or -1 if no such a macro exists.

=item $parser->print_macro($macro)

The argument is a macro structure. Returns the text of the given macro
using the recent style. Clobbers the variable table.

=item $parser->load_id_table()

Populates the local copy if the id table from the saved one. Use before
calling print_expression() for a showing the internal form of a constraint.

=item $parser->get_id_table()

Returns the local copy of the id table filled with the latest variable
names.  Use when adding a new constraint.

=back

=cut
#######################################################

sub new {
    my($class,$session)=@_;
    my $self={session => $session};
    bless $self, $class;
    ## configuration
    my $config = {
      style    => 1,  # 0/1 : 0 - full, 1 - simple
      parent   => 1,  # 0/1 : allow () for grouping
      braces   => 1,  # 0/1 : allow {} for grouping
      varprime => 1,  # 0/1 : prime(s) at the end
      vardig   => 0,  # 0/1/2 : simple style var:  a1, a123
      var_dig  => 0,  # 0/1/2 simple style var: a_1, a_123
      sepchar  => ',',# separator character
      macroarg => 1,  # 0/1 : all macro arguments must be used
      # maximal values
      max_id_no => 20,
      max_id_length => 20,
    };
    foreach my $key (keys %$config){
        my $v=$session->getconf($key);
        $config->{$key}=$v if(defined $v);
    }
    $config->{sepchar} = ';' if(!$config->{style});
    $self->{config}=$config;
    ## syntax error
    $self->{syntax_error} = {
       softerr => "", softerrpos => 0, # out of bound error
       harderr => "", harderrpos => 0, # syntax error
       auxtext => "",                  # additional text
    };
    ## string to be parsed
    $self->{Xstr}=[];    # the string as a char array, closed by \0
    $self->{Xpos}=-1;    # the position we are looking at
    $self->{Xchr}=' ';   # this character
    ## id table
    $self->{id_table}  =[];   # the id string 0 .. MAX_ID_NO-1
    $self->{no_new_id} ="";   # error message if no new id is allowed
    ## macros, always get the full set
    $self->{macros} = wUtils::read_user_macros($session);
    return $self;
}

#############################################################

sub getconf {
    my($self,$key)=@_;
    return $self->{config}->{$key};
}
sub getmacros {
    my($self)=@_;
    return $self->{macros};
}

#############################################################
## Error handling
##
sub clear_errors { # clear all errors
    my($self)=@_;
    $self->{syntax_error}->{softerr}="";
    $self->{syntax_error}->{harderr}="";
    $self->{syntax_error}->{auxtext}="";
}
sub was_harderr {
    my($self)=@_;
    return $self->{syntax_error}->{harderr};
}
sub errmsg {
    my($self,$aux)=@_;
    return $self->{syntax_error}->{auxtext}
       if(defined $aux);
    return $self->{syntax_error}->{harderr} ||
           $self->{syntax_error}->{softerr};
}
sub errpos {
    my($self)=@_;
    return $self->{syntax_error}->{harderr} ?
        $self->{syntax_error}->{harderrpos} :
        $self->{syntax_error}->{softerrpos};
}
sub harderr {
    my($self,$err,$aux)=@_;
    return if($self->was_harderr());
    $self->{syntax_error}->{harderr} = $err;
    $self->{syntax_error}->{harderrpos} = $self->{Xpos};
    $self->{syntax_error}->{auxtext}=$aux if(defined $aux);
}
sub softerr {
    my($self,$err,$aux)=@_;
    return if($self->{syntax_error}->{softerr});
    $self->{syntax_error}->{softerr} = $err;
    $self->{syntax_error}->{softerrpos} = $self->{Xpos};
    return if($self->was_harderr());
    $self->{syntax_error}->{auxtext}=$aux if(defined $aux);
}
##
use constant { ## the error messages
  e_TOO_MANY_ID    => "too many different random variables",
  e_TOO_LONG_ID    => "too long identifier",

  e_NO_CHECK_INPUT => "please enter the relation to be checked",
  e_NO_CONSTR_INPUT=> "please enter a new constraint",
  e_DIGIT_EXPECTED => "a digit is expected after the underscore",
  e_VAR_EXPECTED   => "variable is expected after a comma ','",
  e_GREATER        => "> should be followed by =",
  e_LESS           => "< should be followed by =",
  e_EQUAL          => "? should be followed by =",
  e_INGLETONVAR    => "in Ingleton expression a variable list is expected here",
  e_INGLETONSEP    => "in Ingleton expression a separator character is expected here",
  e_INGLETONCLOSE  => "in Ingleton expression closing ] is missing here",
  e_IEXPR2         => "variable list is missing after | symbol",
  e_CLOSING        => "a closing ')' is expected here",
  e_COMMA_OR_BAR   => "either a list separator or '|' is expected here",
  e_VARLIST        => "variable list is expected here",
  e_CONDEXPR	   => "( should be followed by a variable list",
  e_NOMACRO        => "no macro with this name is defined",
  e_NOMACROARG     => "no macro with this name and pattern is defined",
  e_ENTROPYBRACE   => "missing or wrong entropy expression between { and }",
  e_BRACEEXPECTED  => "a closing '}' is expected here",
  e_ENTROPYPAREN   => "missing or wrong entropy expression between ( and )",
  e_PARENEXPECTED  => "a closing ')' is expected here",
  e_COEFFTERM      => "a coefficient or an entropy term is expected here",
  e_ENTROPYTERM    => "an entropy term is expected here",
  e_NOLHS          => "the left hand side must be either the constant zero, or an entropy expression",
  e_NORELATION     => "there must be an '=', '<=', '>=', or '=?' here",
  e_RELEXPECTED    => "there must be an '=', '<=' or '>=' here",
  e_NORHS          => "the right hand side must be either the constant zero, or an entropy expossion",
  e_EXTRATEXT      => "extra characters at the end",
  e_SIMPLIFIESTO   => "the query simplifies to ",
  e_SIMPLIFIESEND  =>    ", thus it is always TRUE",
  e_POSCOMB        => "the relation is TRUE: a nonnegative combination of entropy values is always >=0",
  e_SINGLETERM     => "the expression simplifies to a single term, no check is performed",
  e_FUNC_EQUAL     => "the first variable set is a function of the second one",
  e_INDEP_AGAIN    => "this variable set occurs earlier - cannot be independent",
  e_INDEP_FUNC     => "the variable set \"",
  e_INDEP_FUNCEND  =>    "\" is a function of others - cannot be independent",
  e_MARKOV         => "a Markov chain must contain at least three tags",
  e_NOMARKOV       => "no need to add as a constraint: this sequence always forms a Markov chain",
  e_COMMONBIG      => "common information can be stipulated for at most 12 variable sets",
  e_NOCOMMON       => "no need to add as a constraint: the first set is the common information of the others",
  e_MDEF_NAME      => "macro definition starts with the macro name - an upper case letter - followed by a '('",
  e_MDEF_NOPAR     => "missing macro argument: a single variable is expected here",
  e_MDEF_SAMEPAR   => "all macro arguments must be different",
  e_MDEF_PARSEPAR  => "a ')', a list separator, or '|' is expected here",
  e_MDEF_NOEQ      => "macro text should start with an '=' symbol",
  e_MDEF_NOTEXT    => "cannot parse the macro text",
  e_MDEF_SIMP0     => "the macro text simplifies to 0, not stored",
  e_MDEF_UNUSED    => "this argument is not used in the final macro text, which is:",
  e_NEWID_IN_MACRO => "only macro arguments can be used as random variables",
};
#############################################################
## Identifiers
##
sub get_id_table {
    my($self)=@_;
    return $self->{id_table};
}
sub clear_id_table { # clear all stored ID's
    my($self)=@_;
    my $id_table=$self->get_id_table();
    for my $i(0 .. $self->getconf("max_id_no")-1){
       $id_table->[$i]="";
    }
}
sub load_id_table { # load user-defined id table
    my($self)=@_;
    my $id_table = $self->get_id_table();
    my $utable = wUtils::read_user_id_table($self->{session});
    for my $i(0 .. $self->getconf("max_id_no")-1){
        $id_table->[$i]= ($utable->[$i] || "");
    }
}
sub no_new_id { # no more new entries, use what is available
    my($self,$msg)=@_;
    $self->{no_new_id} = $msg;
}
sub search_id { # search an ID in the id_table; return the index
    my ($self,$var)=@_;
    my $id_table = $self->get_id_table();
    my $empty_slot=-1;
    my $maxid = $self->getconf("max_id_no")-1;
    for my $i( 0 .. $maxid){
        return $i if( $var eq $id_table->[$i] );
        $empty_slot=$i if($empty_slot<0 && !$id_table->[$i]);
    }
    # not found
    if($self->{no_new_id}) {
        $self->harderr($self->{no_new_id});
        return 0;
    }
    if($empty_slot<0){
        $self->softerr(e_TOO_MANY_ID);
        return $maxid;
    }
    $id_table->[$empty_slot]=$var;
    return $empty_slot;
}
sub get_idlist_repr { # representation of a list of ID's
    my($self,$v)=@_;
    my @unsorted=();
    my $id_table = $self->get_id_table();
    my $style = $self->getconf("style");
    my $i=0;
    while($v){
        if($v&1){
            push @unsorted, $id_table->[$i] || "?";
        }
        $v>>=1; $i++;
    }
    my $res="";
    foreach my $id(sort @unsorted){
        $res .= "," if($res && !$style);
        $res .= $id;
    }
    if(length($res)>200){
       $res=substr($res,0,197)."...";
    }
    return $res;
}
#############################################################
## Entropy expressions
##
sub H1 { # $e += $v*H(a)
    my ($e,$a,$v)=@_;
    $e->{$a}=$v+($e->{$a}||0);
}
sub H2 { # e += v*H(a|b)
     my($e,$a,$b,$v)=@_;
     $e->{$b}= -$v + ($e->{$b}||0);
     $e->{$a|$b}=$v+($e->{$a|$b}||0);
}
sub I2 { # e += v*I(a,b)
    my($e,$a,$b,$v)=@_;
    $e->{$a}=$v+($e->{$a}||0);
    $e->{$b}=$v+($e->{$b}||0);
    $e->{$a|$b}=-$v+($e->{$a|$b}||0);
}
sub I3 { # e += v*I(a,b|c)
    my($e,$a,$b,$c,$v)=@_;
    $e->{$a|$c}=$v+($e->{$a|$c}||0);
    $e->{$b|$c}=$v+($e->{$b|$c}||0);
    $e->{$c}=-$v+($e->{$c}||0);
    $e->{$a|$b|$c}=-$v+($e->{$a|$b|$c}||0);
}
sub collapse_expr { # number and negative entries in $e
    my ($e,$negate)=@_;
    my $n=0; my $g=0;
    foreach my $k (keys %$e){
        my $v=$e->{$k}; 
        if( -EPS <= $v &&  $v<= EPS ){
            delete $e->{$k};
            next;
        }
        if($negate){ $v=-$v; $e->{$k}=$v; }
        $n++;
        $g++ if($v<0);
    }
    return ($n,$g);
}
#############################################################
## Macros
##
#  macro: 
#      { std     => 0/1 (1 if standard, don't report)
#        argno   => number of arguments
#        septype => bitmask for separator ( ; or | )
#        name    => 'A' .. 'Z'
#        text    => entropy expression, hash of
#                    { var1=>coeff1, var2=>coeff2, ...}
sub find_macro { # find macro with the given argno, septype and name
    my($self,$what) = @_;
    my $i=0;
    foreach my $m(@{$self->getmacros()}){
        return $i if($m->{name} eq $what->{name} &&
            $m->{septype}==$what->{septype} &&
            $m->{argno} == $what->{argno});
        $i++;
    }
    return -1;
}
sub find_macro_partial { # find macro with the next separator ; or |
    my($self,$what,$pt)=@_;
    my $mask=(1<<$what->{argno})-1;
    my $type=$what->{septype};
    if($pt){ $type |= (1<<($what->{argno}-1)); }
    foreach my $m (@{$self->getmacros()}){
        return 0 if($m->{name} eq $what->{name} &&
              $m->{argno} > $what->{argno} &&
              ($m->{septype}&$mask)== $type);
    }
    return -1;
}
sub _create_macrovar {
    my($pattern,$args)=@_;
    my $i=0; my $res=0; while($pattern){
       if($pattern&1){$res |= $args->[$i]; }
       $i++; $pattern >>=1;
    }
    return $res;
}
sub add_macrotext { # e += d* (the evaluated macro)
    my($self,$e,$macrono,$args,$d)=@_;
    return if($macrono<0);
    my $text = $self->getmacros()->[$macrono]->{text};
    foreach my $v (keys %$text){
        my $w=_create_macrovar($v,$args);
        $e->{$w}=$d*$text->{$v}+($e->{$w}||0);
    }
}
#############################################################
## print an expression or a macro
##
sub _bitsof {
    my $n=shift; my $v=0;
    while($n){
        $v++ if($n&1); $n>>=1;
    }
    return $v;
}
sub print_expression {
    my($self,$e)=@_;
    my %repr=(); my $total=0;
    foreach my $k (keys %$e){
        $repr{$k}=[_bitsof($k),$self->get_idlist_repr($k)];
        $total++;
    }
    if($total==0){ return "0"; }
    my $res="";
    foreach my $k (sort 
       { $repr{$a}->[0] <=> $repr{$b}->[0] || $repr{$a}->[1] cmp $repr{$b}->[1] }
       keys %repr){
        my $d=$e->{$k};
        if($d<1.0+EPS && $d>1.0-EPS) { $res .="+"; }
        elsif($d<-1.0+EPS && $d>-1.0-EPS) { $res .="-"; }
        else { $res .= sprintf("%+g",$d); }
        if($self->getconf("style")){ # simple
            $res .= $repr{$k}->[1];
        } else {
            $res .= "H(".$repr{$k}->[1].")";
        }
    }
    $res =~ s/^\+//;
    return $res;
}
sub print_macro { # clobbers the id table
    my ($self,$macro)=@_;
    my $X_sep=$self->getconf("sepchar");
    return "" if(!defined $macro);
    my $res = $macro->{name}."(";
    my $baseletter= $self->getconf("style") ? ord('a') : ord('A');
    my $septype = $macro->{septype};
    # one can save the id table here and restore later
    $self->clear_id_table();
    for my $v(0..$macro->{argno}-1){
        my $arg=chr($v+$baseletter);
        $self->search_id($arg);
        $res .= $arg . ($v==$macro->{argno}-1 ? ")" : ($septype&1) ? "|" : $X_sep);
        $septype >>=1 ;
    }
    $res .= "=" . $self->print_expression($macro->{text});
    return $res;
}
#############################################################
## Character parsing
##
sub next_chr { # get next visible char
    my($self)=@_;
    do { 
       $self->{Xpos}++;
       $self->{Xchr}=$self->{Xstr}->[$self->{Xpos}]; 
    } while ( $self->{Xchr} eq ' ' );
}
sub next_visible { # skip to the next visible char
    my($self)=@_;
    while($self->{Xchr} eq ' '){
       $self->{Xpos}++;
       $self->{Xchr}=$self->{Xstr}->[$self->{Xpos}]; 
    }
}
sub next_idchr { # next ID character
    my($self)=@_;
    $self->{Xpos}++;
    $self->{Xchr}=$self->{Xstr}->[$self->{Xpos}];
}
sub save_pos {
    my($self)=@_;
    return $self->{Xpos};
}
sub restore_pos {
    my($self,$oldpos)=@_;
    $self->{Xpos}=$oldpos; 
    $self->{Xchr}=$self->{Xstr}->[$self->{Xpos}];
}
sub init_parse {
    my($self,$string)=@_;
    $string =~ s/\t/ /g;
    my @X_str = split('',$string."\x0");
    $self->{Xstr}=\@X_str;
    $self->{Xpos}=-1; 
    $self->next_chr();
}
sub R { # check if the next char is chr
    my($self,$chr)=@_;
    return 0 if($self->{Xchr} ne $chr);
    ## $self->next_chr();
    do { 
       $self->{Xpos}++;
       $self->{Xchr}=$self->{Xstr}->[$self->{Xpos}]; 
    } while ( $self->{Xchr} eq ' ' );
    return 1;
}
sub expect_oneof { # expect one of three characters
    my($self,$c1,$c2,$c3)=@_;
    return 1 if($c1 && $self->R($c1));
    return 2 if($c2 && $self->R($c2));
    return 3 if($c3 && $self->R($c3));
    return 0 if($self->was_harderr());
    my $n=0; $n++ if($c1); $n++ if($c2); $n++ if ($c3);
    if($n==1){
        $self->harderr(sprintf("the symbol %s is expected here",$c1||$c2||$c3));
    } elsif($n==2){
        $self->harderr(sprintf("either %s or %s is expected here",($c1||$c2),($c3||$c2)));
    } else {
        $self->harderr("one of $c1, $c2, or $c3 is expected here");
    }
    return 0;
}
#############################################################
## Numbers
##
sub is_digit { # when a digit, return the value
    my($self)=@_;
    return 0 if ($self->{Xchr} lt '0' || $self->{Xchr} gt '9');
    $_[1]=ord($self->{Xchr})-ord('0');
    ## $self->next_chr();
    do { 
       $self->{Xpos}++;
       $self->{Xchr}=$self->{Xstr}->[$self->{Xpos}]; 
    } while ( $self->{Xchr} eq ' ' );
    return 1;
}
sub frac_part { # /\.\d+/
    my($self)=@_;
    my $oldpos=$self->save_pos(); my $i=0;
    if($self->R('.') && $self->is_digit($i)){
        my $scale=0.1; my $v=$scale * $i;
        while($self->is_digit($i)){
            $scale *=0.1; $v+= $scale *$i;
        }
        $_[1]=$v;
        return 1;
    }
    $self->restore_pos($oldpos);
    return 0;
}
sub is_number { # \d+ | \d?\.\d+ 
    my($self)=@_;
    my $i=0;
    if($self->is_digit($i)){
        my $v=$i;
        while($self->is_digit($i)){ $v=$v*10.0+$i; }
        my $w=0.0; $self->frac_part($w);
        $_[1]=$v+$w;
        return 1;
    }
    return $self->frac_part($_[1]);
}
# single +, -, or a number optionally followed by a *
sub is_signed_number {
    my($self)=@_;
    my $v=1.0;
    if($self->R('+')){
        $self->is_number($v) && $self->R('*'); $_[1]=$v;
        return 1;
    }
    if($self->R('-')){
        $self->is_number($v) && $self->R('*'); $_[1]=-$v;
        return 1;
    }
    if($self->is_number($_[1])){
        $self->R('*');
        return 1;
    }
    return 0;
}
sub is_zero { # zero number
    my($self)=@_;
    my $v=0; my $oldpos=$self->save_pos();
    return 1 if($self->is_number($v) && -EPS<=$v && $v <= EPS);
    $self->restore_pos($oldpos);
    return 0;
}
#############################################################
## Identifier, list of identifiers
##
sub is_variable {
    my($self)=@_;
    my $var="";
    if($self->getconf("style")){ ## simple style
        if($self->{Xchr} =~ /[a-z]/ ){
            $var=$self->{Xchr}; $self->next_idchr();
            if( $self->getconf("var_dig") && $self->{Xchr} eq '_'){
                $self->next_idchr(); if($self->{Xchr} =~ /\d/){
                    $var .= "_$self->{Xchr}"; $self->next_idchr();
                    while($self->getconf("var_dig")>1 && $self->{Xchr} =~ /\d/){
                        $var .= $self->{Xchr}; $self->next_idchr();
                    }
                } else { $self->harderr(e_DIGIT_EXPECTED); }
            } elsif($self->getconf("vardig") && $self->{Xchr} =~ /\d/ ){
                $var .= $self->{Xchr}; $self->next_idchr();
                while($self->getconf("vardig")>1 && $self->{Xchr} =~ /\d/){
                   $var .= $self->{Xchr}; $self->next_idchr();
                }
            }
        }
    } else { # full style 
        if( $self->{Xchr} =~ /[A-Za-z]/ ){
            $var=$self->{Xchr}; $self->next_idchr();
            while( $self->{Xchr} =~ /^\w/ ){
                $var .= $self->{Xchr}; $self->next_idchr();
            }
        }
    }
    return 0 if(!$var);
    if($self->getconf("varprime")){
        while($self->{Xchr} eq '\''){ $var .= '\''; $self->next_idchr(); }
    }
    if(length($var)>$self->getconf("max_id_length")){
        softerr(e_TOO_LONG_ID);
    }
    $self->next_visible();
    $_[1]=1<< ($self->search_id($var));
    return 1;
}
sub is_varlist {
    my ($self)=@_;
    my($v,$w)=(0,0);
    if($self->is_variable($v)){
        if($self->getconf("style")){ #simple
            while($self->is_variable($w)){ $v |= $w; }
        } else { # full
            while($self->R(',')){
               $self->is_variable($w)||$self->harderr(e_VAR_EXPECTED);
               $v |= $w;
            }
        }
        $_[1]=$v;
        return 1;
    }
    return 0;
}
sub is_macro_name {
    my($self)=@_;
    if($self->{Xchr} =~ /[A-Z]/){
        $_[1]=$self->{Xchr};
        ## $self->next_chr();
        do { 
           $self->{Xpos}++;
           $self->{Xchr}=$self->{Xstr}->[$self->{Xpos}]; 
        } while ( $self->{Xchr} eq ' ' );
        return 1;
    }
    return 0;
}
#############################################################
## Relation symbol
##
sub is_zapped { # will it result in =?
    my($str)=@_;
    return 1 if($str =~ /=\s*[\?=]/ );
    return 1 if($str =~ /\?\s*=/ );
    return 0;
}
sub is_relation { # one of =, <=, >=, =?
    my($self)=@_;
    my $relsym="";
    if($self->R('=')){
        $relsym = "=";
        $relsym .= "?" if( $self->R('?')||$self->R('='));
    } elsif( $self->R('<') ){
        $relsym = "<=";
        $self->R('=') || $self->harderr(e_LESS);
    } elsif( $self->R('>') ){
        $relsym = ">=";
        $self->R('=') || $self->harderr(e_GREATER);
    } elsif( $self->R('?') ){
        $relsym="=?";
        $self->R('=') || $self->harderr(e_EQUAL);
    }
    if($relsym){ $_[1]=$relsym; return 1; }
    return 0;
}
#############################################################
## Entropy terms
##
sub is_Ingleton {
    my ($self,$e,$v)=@_;
    my $X_sep =$self->getconf("sepchar");
    if($self->R('[')){
        my($a,$b,$c,$d)=(0,0,0,0);
        $self->is_varlist($a) || $self->harderr(e_INGLETONVAR);
        $self->R($X_sep) || $self->harderr(e_INGLETONSEP);
        $self->is_varlist($b) || $self->harderr(e_INGLETONVAR);
        $self->R($X_sep) || $self->harderr(e_INGLETONSEP);
        $self->is_varlist($c) || $self->harderr(e_INGLETONVAR);
        $self->R($X_sep) || $self->harderr(e_INGLETONSEP);
        $self->is_varlist($d) || $self->harderr(e_INGLETONVAR);
        $self->R(']') || $self->harderr(e_INGLETONCLOSE);
        # [a,b,c,d] =-(a,b)+(a,b|c)+(a,b|d)+(c,d)
        I2($e,$a,$b,-$v); I3($e,$a,$b,$c,$v);
        I3($e,$a,$b,$d,$v); I2($e,$c,$d,$v);
        return 1;
    }
    return 0;
}
sub is_par_expression { # (a,b) (a|b) (a,b|c)
    my ($self,$e,$v)=@_;
    return 0 if(!$self->getconf("style"));
    my $oldpos=$self->save_pos(); my($a,$b,$c)=(0,0,0);
    if($self->R('(') && $self->is_varlist($a)){
       if($self->R('|')){ # (a|b)
           $self->is_varlist($b) || $self->harderr(e_IEXPR2);
           $self->R(')') || $self->harderr(e_CLOSING);
           H2($e,$a,$b,$v);
           return 1;
       }
       if($self->R($self->getconf("sepchar"))){
           $self->is_varlist($b) || $self->harderr(e_VARLIST);
           if($self->R('|')){ # (a,b|c)
               $self->is_varlist($c) || $self->harderr(e_VARLIST);
               I3($e,$a,$b,$c,$v);
           } else { # (a,b)
               I2($e,$a,$b,$v);
           }
           $self->R(')') || $self->harderr(e_CLOSING);
           return 1;
       }
       $self->getconf("parent") || $self->harderr(e_COMMA_OR_BAR);
    }
    $self->restore_pos($oldpos);
    return 0;
}
sub is_simple_expression { # a a,b  a|b  a,b|c
    my ($self,$e,$v)=@_;
    return 0 if(!$self->getconf("style"));
    my($a,$b,$c)=(0,0,0);
    if($self->is_varlist($a)){
        if($self->R('|')){
            $self->is_varlist($b) || $self->harderr(e_IEXPR2);
            H2($e,$a,$b,$v);
        } elsif($self->R($self->getconf("sepchar"))){ # a,b
            $self->is_varlist($b) || $self->harderr(e_VARLIST);
            if($self->R('|')){ # a,b|c
                $self->is_varlist($c) || $self->harderr(e_VARLIST);
                I3($e,$a,$b,$c,$v);
            } else {
                I2($e,$a,$b,$v);
            }
        } else { # a
            H1($e,$a,$v);
        }
        return 1;
    }
    return 0;
}
sub is_macro_invocation { # 3.14*A(ab,ac|ad|ae)
    my ($self,$e,$coeff)=@_; my $name="";
    my $oldpos=$self->save_pos();
    if($self->is_macro_name($name) && $self->R('(')){
        my $what={name => $name, argno => 0, septype => 0, args => [] };
        if($self->find_macro_partial($what,0)<0){
            $self->restore_pos($oldpos);
            $self->harderr(e_NOMACRO);
            return 0;
        }
        for(my $done=0;!$done;){
          my $v=0; $self->is_varlist($v) || $self->harderr($what->{argno}?e_VARLIST : e_CONDEXPR);
          push @{$what->{args}},$v;
          $what->{argno}++;
          my $nextch=$self->expect_oneof(
              ($self->find_macro($what)>=0 ? ')' : ""), # we have such a macro
              ($self->find_macro_partial($what,0)>=0 ? $self->getconf("sepchar") : ""), 
              ($self->find_macro_partial($what,1)>=0 ? '|' : ""));
          if($nextch==1){ # )
              $done=1;
          } elsif($nextch==2){ # sep
          } elsif($nextch==3){ # |
              $what->{septype} |= (1<<($what->{argno}-1));
          } else { # error
              $done=1;
          }
        }
        my $macrono=$self->find_macro($what);
        $macrono>=0 || $self->harderr(e_NOMACROARG);
        $self->add_macrotext($e,$macrono,$what->{args},$coeff);
        return 1;
    }
    $self->restore_pos($oldpos);
    return 0;
}
#############################################################
## Entropy expression
##
sub coeff_term { # term preceeded by an optional coefficient
    my($self,$e,$d)=@_;
    my $oldpos=$self->save_pos();
    my $coeff=1.0; $self->is_signed_number($coeff);
    $coeff *= $d;
    return 1 if(
       $self->is_Ingleton($e,$coeff) ||
       $self->is_par_expression($e,$coeff) ||
       $self->is_simple_expression($e,$coeff) ||
       $self->is_macro_invocation($e,$coeff) );
   if($self->getconf("braces") && $self->R('{')){
       $self->entropy_expression($e,$coeff) || $self->harderr(e_ENTROPYBRACE);
       $self->R('}') || $self->harderr(e_BRACEEXPECTED);
       return 1;
   }
   if($self->getconf("parent") && $self->R('(')){
       $self->entropy_expression($e,$coeff) || $self->harderr(e_ENTROPYPAREN);
       $self->R(')') || $self->harderr(e_PARENEXPECTED);
       return 1;
   }
   $self->restore_pos($oldpos);
   return 0;
}
sub entropy_expression { # sequence of entropy terms separated by +/-
    my ($self,$e,$d)=@_;
    return 0 if($self->was_harderr());
    if($self->coeff_term($e,$d)){
        while(!$self->was_harderr() && $self->{Xchr} =~ /[+\-]/){
          $self->coeff_term($e,$d) ||
             $self->harderr($self->is_signed_number($d) ? e_ENTROPYTERM : e_COEFFTERM);
        }
        return 1;
    }
    return 0;
}
#############################################################
## Entropy relation
##
#   $result->{text} -- the expression reduced to =,>=, =?
#   $result->{rel}  -- the relation, one of  =, >=, <=, =?
sub _parse_relation {  # relation or constraint
    my($self,$result,$zap)=@_;
    my $e={};          # the expression
    my $relsym="";     # relation, one of "=" "<=" ">=" or "=?" when $zap
    $self->entropy_expression($e,1.0) || $self->is_zero() || $self->harderr(e_NOLHS);
    $self->is_relation($relsym) || $self->harderr($zap ? e_NORELATION : e_RELEXPECTED);
    $zap || $relsym ne "=?" || $self->harderr(e_RELEXPECTED);
    $self->entropy_expression($e,-1.0) || $self->is_zero() || $self->harderr(e_NORHS);
    $self->{Xchr} eq "\0" || $self->harderr(e_EXTRATEXT);
    # convert it to =0, >=0, =?
    my ($n,$g)=collapse_expr($e, $relsym eq "<=");
    if( $relsym ne "=?"){ # = or >= or <=
       $n || $self->softerr(e_SIMPLIFIESTO . "0 $relsym 0" . e_SIMPLIFIESEND);
       $g || $relsym eq "=" || $self->softerr(e_POSCOMB,$self->print_expression($e));
       !$zap || $n>1 || $self->softerr(e_SINGLETERM,$self->print_expression($e));
    }
    $result->{text}= $e;
    $result->{rel} = ($relsym eq "<=" ? ">=" : $relsym);
}
sub parse_relation {
    my($self,$result,$str,$standalone)=@_;
    $self->clear_errors();
    # clear or load the id table
    if($standalone || is_zapped($str) ){ $self->clear_id_table(); }
    else { $self->load_id_table(); }
    $self->init_parse($str);
    $str !~ /^\s*$/ || $self->harderr(e_NO_CHECK_INPUT);
    $self->_parse_relation($result,1); # =? allowed
}
#############################################################
## Constraint
##
#   it can be a RELATION or one of the following:
#    a : b       or
#    a << b      functional dependence
#    a . b . c   or
#    a || b || c totally independent
#    a / b / c   or
#    a -> b-> c  Markov chain
#    a << b / c  common information
#    $result->{text}-- expression for "=" and ">="; 
#                      array of expressions for "markov" or "common"
#    $result->{rel} -- one of "=", ">=", "markov", "common"
sub _funcdep {
    my($self,$result,$v1,$v2)=@_;
    $v1 |= $v2;
    $v1!=$v2 || $self->harderr(e_FUNC_EQUAL);
    $self->{Xchr} eq "\0" || $self->harderr(e_EXTRATEXT);
    $result->{rel}  ="=";
    $result->{text} = { "$v1" => 1, "$v2" => -1 };
}
sub _indep {
    my($self,$result,$sep,$v1,$v2)=@_;
    my $e= {"$v1" => 1, "$v2" => 1,};
    my $vall = $v1|$v2;
    my $oldpos;
    $v1 != $v2 || $self->harderr(e_INDEP_AGAIN);
    if($sep eq '.'){
        while( ($oldpos=$self->save_pos())
          && $self->R('.') && $self->is_varlist($v2) ){
            !$e->{$v2} || $self->harderr(e_INDEP_AGAIN);
            $vall |= $v2;
            $e->{$v2} =1;
        }
        $self->restore_pos($oldpos);
    } else {
        while( ($oldpos=$self->save_pos()) 
          && $self->R('|') && $self->R('|') 
          && $self->is_varlist($v2) ){
            !$e->{$v2} || $self->harderr(e_INDEP_AGAIN);
            $vall |= $v2;
            $e->{$v2} = 1;
        }
        $self->restore_pos($oldpos);
    }
    $self->{Xchr} eq "\0" || $self->harderr(e_EXTRATEXT);
    # check if none of them is a function of others
    foreach my $k(keys %$e){
        $v1=0; foreach my $k2(keys %$e){
            next if($k==$k2);
            $v1 |= $k2;
        }
        $v1!=$vall || $self->harderr(
            e_INDEP_FUNC . $self->get_idlist_repr($k) . e_INDEP_FUNCEND );
    }
    $e->{$vall} = -1;
    $result->{text}=$e;
    $result->{rel} ="=";
}
sub unfold_markov { # unfold the Markov Chain
    my($vars)=@_;
    my @allexp=(); my %hashed=(); $hashed{""}=1;
    for my $cnt(1 .. scalar @$vars-2){
        my ($i,$v1,$v,$v2)=(0,0,0,0);
        foreach my $var(@$vars){
           if($i<$cnt){ $v1|=$var; }
           elsif($i==$cnt){ $v=$var; }
           else {$v2 |= $var; }
           $i++;
        } # ($v1,$v2|$v)=0
        my $e={}; I3($e,$v1,$v2,$v,1);
        my $hash="";
        foreach my $k (sort {$a <=> $b} keys %$e){
            my $v=$e->{$k};
            if( -EPS <= $v && $v<= EPS ){
                delete $e->{$k};
                next;
            }
            $hash .= "$k,$v,";
        }
        next if ($hashed{$hash});
        $hashed{$hash}=1;
        push @allexp, $e;
    }
    return \@allexp;
}
sub _Markov {
    my($self,$result,$sep,$v1,$v2)=@_;
    my $cnt=2; my @e=($v1,$v2);
    my $oldpos=0;
    if($sep eq '/'){
       while( ($oldpos=$self->save_pos())
         && $self->R('/') && $self->is_varlist($v2) ){
           push @e,$v2; $cnt++;
       }
       $self->retore_pos($oldpos);
    } else {
       while( ($oldpos=$self->save_pos())
         && $self->R('-') && $self->R('>')
         && $self->is_varlist($v2) ){
           push @e,$v2; $cnt++;
       }
       $self->restore_pos($oldpos);
    }
    $self->{Xchr} eq "\0" || $self->harderr(e_EXTRATEXT);
    $cnt >=3 || $self->harderr(e_MARKOV);
    $result->{text}=unfold_markov(\@e);
    scalar @{$result->{text}}>0 || $self->softerr(e_NOMARKOV);
    $result->{rel} ="markov";
}
sub unfold_common { # unfold common information
    my($v,$vars)=@_; 
    my @allexp=(); my %hashed=(); $hashed{""}=1;
    for my $w (@$vars){ # wv = w
        my $wv=$w|$v; next if($wv==$w);
        my $e={"$wv"=>1, "$w"=> -1}; 
        my $hash="$wv,1,$w,-1";
        next if($hashed{$hash});
        $hashed{$hash}=1;
        push @allexp,$e;
    }
    # v= a+b+c-ab-bc-ac+abc
    my $e={ "$v" => -1 };
    for my $A ( 1 .. -1+(1<<(scalar @$vars)) ){
        my $s=-1; my $w=0; my $i=0;
        while($A){
            if($A&1){
                $w |= $vars->[$i];
                $s=-$s;
            }
            $A>>=1; $i++;
        }
        $e->{$w} = ($e->{$w}||0)+$s;
    }
    my $hash1=""; my $hash2="";
    foreach my $k (sort {$a <=> $b} keys %$e){
        my $v=$e->{$k};
        if( -EPS <=$v && $v<= EPS ){
            delete $e->{$k};
            next;
        }
        $hash1 .= "$k,$v,"; $v=-$v; $hash2 .= "$k,$v,";
    }
    push @allexp, $e if( !$hashed{$hash1} && !$hashed{$hash2} );
    return \@allexp;
}
sub _common_info {
    my($self,$result,$v1,$v2,$v3)=@_;
    my @e=($v2,$v3); my $oldpos=0; my $cnt=2;
    while(($oldpos=$self->save_pos())
       && $self->R('/') && $self->is_varlist($v3) ){
         push @e,$v3 if($cnt<15);
         $cnt++;
    }
    $self->restore_pos($oldpos);
    $self->{Xchr} eq "\0" || $self->harderr(e_EXTRATEXT);
    $cnt<16 || $self->softerr(e_COMMONBIG);
    $result->{text}=unfold_common($v1,\@e);
    scalar @{$result->{text}}>0 || $self->softerr(e_NOCOMMON);
    $result->{rel}="common";
}
sub parse_constraint {
    my($self,$result,$str)=@_;
    my $v1=0; my $v2=0;
    $self->clear_errors();
    $self->load_id_table();
    $self->init_parse($str); my $oldpos=$self->save_pos();
    $str !~ /^\s*$/ || $self->harderr(e_NO_CONSTR_INPUT);
    $result->{raw}=$str;
    if($str !~ /=/ && $self->is_varlist($v1)){
        if($self->R(':')){
            if($self->is_varlist($v2)){
                $self->_funcdep($result,$v1,$v2);
                return; 
            }
        } elsif($self->R('<')){
            if($self->R('<') && $self->is_varlist($v2)){
               my $oldpos=$self->save_pos(); my $v3=0;
               if($self->R('/') && $self->is_varlist($v3)){ 
                   $self->_common_info($result,$v1,$v2,$v3);
                   return;
               }
               $self->restore_pos($oldpos);
               $self->_funcdep($result,$v1,$v2);
               return;
            }
        } elsif($self->R('.')){
            if($self->is_varlist($v2)){
                $self->_indep($result,'.',$v1,$v2);
                return; 
            }
        } elsif($self->R('|')){
            if($self->R('|') && $self->is_varlist($v2)){ 
                $self->_indep($result,'|',$v1,$v2);
                return; 
            }
        } elsif($self->R('/')){
            if($self->is_varlist($v2)){
                $self->_Markov($result,'/',$v1,$v2);
                return;
            }
        } elsif($self->R('-')){
            if($self->R('>') && $self->is_varlist($v2)){
                $self->_Markov($result,'-',$v1,$v2);
                return;
            }
        }
    }
    $self->restore_pos($oldpos);
    $self->_parse_relation($result,0); # =? not allowed
}    
#############################################################
## Macro
##
sub parse_macro_definition {
    my($self,$macro,$str)=@_;
    my $e={};            # macro text
    my $name="A";        # macro name
    my $arg=0;           # argument number
    my $X_sep=$self->getconf("sepchar");
    $self->clear_errors();      # no error so far
    $self->clear_id_table();    # don't use previous id's
    $self->init_parse($str);    # parse this string
    ( $self->is_macro_name($name) && $self->R('(') ) 
      || $self->harderr(e_MDEF_NAME);
    $macro->{name}=$name; $macro->{argno}=0; $macro->{septype}=0;
    $macro->{std}=0; $macro->{text}=$e; $macro->{raw}=$str;
    my $parpos=$self->save_pos();   # position of first parameter
    for(my $done=0; !$done; ){
        $self->is_variable($arg) || $self->harderr(e_MDEF_NOPAR);
        $arg == (1<<$macro->{argno}) || $self->harderr(e_MDEF_SAMEPAR);
        if($self->R($X_sep)){
            ;
        } elsif($self->R('|')){
            $macro->{septype} |= 1<<$macro->{argno};
        } else {
            $self->R(')') || $self->harderr(e_MDEF_PARSEPAR);
            $done=1;
        }
        $macro->{argno}++;
    }
    $self->R('=') || $self->harderr(e_MDEF_NOEQ);
    return if( $self->errmsg() );
    $self->no_new_id(e_NEWID_IN_MACRO);
    $self->entropy_expression($e,1.0) || $self->harderr(e_MDEF_NOTEXT);
    $self->{Xchr} eq "\0" || $self->harderr(e_EXTRATEXT);
    my($n,$g)=collapse_expr($e,0);
    $n || $self->softerr(e_MDEF_SIMP0);
    if($self->getconf("macroarg")){ # all arguments must be used
        $n=0; foreach my $k(keys %$e){ $n |= $k; }
        $g=1; while($n&1){ $g++; $n>>=1; }
        if($g<=$macro->{argno}){ ## show which argument is unused
           $self->restore_pos($parpos);
           while($g>1){
               $g--; $self->is_variable($arg); $self->R($X_sep)||$self->R('|');
           }
           $self->is_variable($arg);
           $self->softerr(e_MDEF_UNUSED,$self->print_expression($e));
        }
    }
}

1;

