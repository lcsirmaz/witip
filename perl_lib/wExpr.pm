####################
## wExpr.pm
####################
##
## handle expressions
##
###########################################################################
# This code is part of wITIP (a web based Information Theoretic Prover)
#
# Copyright (2017) Laszlo Csirmaz, Central European University, Budapest
# This program is free, open-source software. You may redistribute it
# and/or modify under the terms of the GNU General Public License (GPL).
# There is ABSOLUTELY NO WARRANTY, use at your own risk.
###########################################################################

package wExpr;

use wUtils;
use wParser;
use strict;

#######################################################
=pod

=head1 wITIP perl modules

=head2 wExpr.pm

Parse and execute queries received as ajax requests.

=head2 Data structure

=over 2

=item Result

The return value is a hash with the following fields:

    res     => number, indicating the result type (see below)
    label   => integer, request number when result >= 3
    err     => the error text
    pos     => the position where the error was found
    aux     => auxiliary error text

The res field is one of the following:

    1 => syntax error, fields err, pos, aux are filled
    2 => unroll, the unrolled text is in aux
    3 => result is pending, label is the request number (unique within SSID)
    4 => request LP timeout
    5 => request failed (some LP problem)
    6 => the relation is TRUE
    7 => the relation is FALSE
    8 => only >= is true
    9 => only <= is true

=item History

Requests (with results) are stored in the expression history file.  Each
history item takes a line organized as follows:

I<type>,I<label>,I<standalone>,I<text>

Here I<type> is a digit as in the "res" field above except for 1 which cannot
occur. I<label> is an integer identifying the request uniquely; I<standalone>
is 0 or 1 showing whether the request was evaluated without (0) or with (1)
constraints.  Finally, I<text> is the request; unrolled form added after
'+++' for type 2.  When a pending request is completed, additional line is
added to the history file where I<standalone> is 2.  The history stores the
content of the editing field with I<type> equal to 99.

=item Pending requests

Syntactically correct requests are passed to the wMakeLP::parse_relation()
which generates an LP instance and the LP solver is launched.  After setting
up the problem the solver returns, leaving behind a background process. 
That background process writes the answer (solution) to a result file.  Each
request is assigned a unique label (integer) which is returned, and can be
used to enquire about pending jobs.

=back

=head2 Procedures

=over 2

=item $result = wExpr::check_expr($session,$string,$standalone)

Parse the $string as a query.  When $standalone is set, the relation is to
be checked without constraints (the id table is not loaded).  Returns a hash
as explained above.  The res field shows the result, other fields are filled
only when contain relevant information.

When successful, the query string $string with the result code is added to the
history.

=item ($code,$history) = wExpr::check_result($session,$label)

Check if the job identified by $label has finished.  If yes, remove (unlink)
both the problem and the result files.  The returned code is the one as
indicated in the return structure.  $history is the string to be put into
the expression history file, or empty if the job did not finish yet.

In some cases calls to check_result() may overlap resulting in loss of
information about some jobs.  If for a pending request the LP problem file
is not found, then we assume that this is the case, and return a failure
indication, even if the history file contains the right answer.

=back

=cut
#######################################################

sub check_result {
   my($session,$label)=@_;
   my ($res,$history)=(3,"");
   my $lpresfile=$session->{stub}.".${label}.res";
   my $lpproblem=$session->{stub}.".${label}.lp";
   my $fh;
   if(-s $lpresfile && open($fh,"<",$lpresfile)){ # problem solved
      my $txt=<$fh>; chomp $txt;
      close($fh);
      # for these codes see the documentation of glpksolve.c
      $res=-1;
      $res= 6 if($txt eq "0"); # TRUE
      $res= 7 if($txt eq "1"); # FALSE
      $res= 9 if($txt eq "2"); # <= only
      $res= 8 if($txt eq "3"); # >= only
      $res= 5 if($txt eq "4"); # LP failed
      $res= 4 if($txt eq "5"); # timeout
      if($res>=0){
         unlink($lpresfile,$lpproblem);
      } else {
         print STDERR "Unknown result code $txt for lpresult $lpresfile\n";
         $res=5; # failed
      }
      $history="$res,$label,2,,";
    } elsif(! -e $lpproblem ){ # has been deleted meanwhile
      $res=5;
      $history="$res,$label,2,,";
    }
    return ($res,$history);
}

sub check_expr {
    my($session,$string,$standalone)=@_;
    my $parser=new wParser($session);
    my $result={};
    $parser->parse_relation($result,$string,$standalone);
    # don't process if there was an error
    return { res=> 1,
             err=> $parser->errmsg(),
             pos=> $parser->errpos(),
             aux=> $parser->errmsg("aux")
    } if($parser->errmsg());
    wUtils::set_modified($session);
    my $label=wUtils::get_label($session);
    if($result->{rel} eq "=?"){ # unroll request
        my $unr=$parser->print_expression($result->{text});
        wUtils::write_user_history($session,"expr","2,$label,1,$string+++$unr");
        return { res   => 2,
                 label => $label,
                 aux   => $unr };
    }
    # the expression to be checked is in $result->{text}
    my $lpfile=$session->{stub}.".$label.lp";
    my $lpresfile=$session->{stub}.".$label.res";
    use wMakelp;
    my $makelp= new wMakeLP($session);
    my $genresult= $makelp->generate_LP(
        $lpfile, $result,
        $standalone ? [] : wUtils::read_user_constraints($session));
    if($genresult){
        print STDERR "generate LP for $lpfile failed with $genresult\n";
        wUtils::write_user_history($session,"expr","5,$label,$standalone,$string\n");
        return { res => 5, label => $label }; # LP failed
    }
    # execute LP
    system($session->getconf("lpsolver"),"$lpfile","$lpresfile");
    if($?<0 || ($?>>8)!=0){
        print STDERR "executing lpsolver for $lpfile returned error code $?\n";
        wUtils::write_user_history($session,"expr","5,$label,$standalone,$string\n");
        return { res => 5, label => $label }; # LP failed
    }
    # check result, if any
    my ($res,$hist)=wExpr::check_result($session,$label);
    wUtils::write_user_history($session,"expr","$res,$label,$standalone,$string\n");
    return { res => $res, label => $label };
}

1;

