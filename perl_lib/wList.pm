####################
## wList.pm
####################
##
##  create an executable list of commands; execute it
##
###########################################################################
# This code is part of wITIP (a web based Information Theoretic Prover)
#
# Copyright 2017-2024 Laszlo Csirmaz, UTIA, Prague
# This program is free, open-source software. You may redistribute it
# and/or modify under the terms of the GNU General Public License (GPL).
# There is ABSOLUTELY NO WARRANTY, use at your own risk.
###########################################################################

package wList;

use wHtml;
use wUtils;
use strict;

################################################################
=pod

=head1 wITIP perl modules

=head2 wLis.pm

Create an executable list for macros, constraints, and the last query.
Execute such a list.

=head2 Command format

The first line in the file MUST BE

    #!witip <style> sepchar=<char>

where <style> is either 'traditional' or 'simple'. The actual separator
character is added. Further lines starting with # are ignored. Lines

    clear macros
    clear constraints

clear these tables. Macros, constraints and a single query are added as

    macro M(a,b,c)=a+b+c-ab-bc-ca+abc
    constraint enabled|disabled  a->b->c
    query (a,b)=a+b-ab

Lines after the query line is skipped. The file length cannot exceed 0.5M,
and the line length is maximized to 5000. The execution stops when an error
is encountered.

=head2 Procedures

=over 2

=item wList::Create($session)

Print out the command list creating the present set of macros and constraints.

=item wList::Execute($session,$fh)

Execute commands in the file identified by the file handle $fh. Return the
error message, if any.

=back

=cut
################################################################

# order macros by name, then by argument number, then
# by argument type.
sub _cmpmacros {
    my($a,$b)=@_;
    if($a->{name} ne $b->{name}){
        return $a->{name} cmp $b->{name};
    }
    if($a->{argno} != $b->{argno}){
        return $a->{argno} <=> $b->{argno};
    }
    return $a->{septype} <=> $b->{septype};
}

sub Create {
    my($session)=@_;
    # macros
    print "# macros\r\n";
    print "clear macros\r\n";
    my $macrolist=wUtils::read_user_macros($session);
    foreach my $macro (sort {_cmpmacros($a,$b)} @$macrolist ){
       next if($macro->{std});
       print "macro ",$macro->{raw},"\r\n";
    }
    #constraints
    print "# constraints\r\n";
    print "clear constraints\r\n";
    my $constrlist=wUtils::read_user_constraints($session);
    foreach my $ctr (@$constrlist){
      my $enabled="enabled";
      $enabled="disabled" if($ctr->{skip});
      print "constraint $enabled ",$ctr->{raw},"\r\n";
    }
    # last query
    use wMainPage;
    my $lines=wMainPage::parse_expr_history($session) -> {hist};
    if(scalar @$lines == 0){
        print "# no query \r\n";
        return;
    }
    my $expr=$lines->[-1+scalar @$lines];
    my($type,$text)=($expr->[0],$expr->[3]);
    if($type==2){
       $text =~ s/\+\+\+.*$//;
    }
    print "query ",$text,"\r\n";
    return;
}

###############################################################

sub render_error {
    my($session,$line,$prefix,$str,$err)=@_;
    if($err->{pos}<0 || $err->{pos} >= length($str)){ $err->{pos}=0; }
    my $ttattribs="style=\"font-family: " . $session->getconf("font")
       . "; font-size: " . $session->getconf("fontsize") . "pt;\"";
    my $before=wUtils::htmlescape(substr($str,0,$err->{pos}));
    my $after=wUtils::htmlescape(substr($str,$err->{pos}));
    my $txt="There was an error in line $line of the uploaded file:\n" 
     . "<div class=\"errline\" $ttattribs>"
     . "<span class=\"errbefore\">$prefix $before</span>"
     . "<span class=\"errpos\"></span>"
     . "<span class=\"errafter\">$after</span></div>"
     . "<div class=\"errtxt\">" . wUtils::htmlescape($err->{err}) . "</div>\n";
    if($err->{aux}){
       $txt .= "\n<div class=\"erraux\" $ttattribs\">"
        . wUtils::htmlescape($err->{aux}) ."</div>";
    }
    return $txt;
}

sub Execute {
    my($session,$fh,$origname)=@_;
    my $io;
    if(!open($io,"<",$fh)){ return "Command file \"$origname\" was not received"; }
    # do not accept too large files
    if( (stat($io))[7] > 500000 ){
        close($io);
        return "Command file size exceeds the maximal allowed amount";
    }
    my $line=<$io>; my $lineno=1;
    my($type,$sepchar)=("","");
    if( $line =~ /\#!witip (\w+) sepchar=(.)/ ){
       $type=$1; $sepchar=$2;
    }
    if($sepchar){
       my $found=0;
       foreach my $t(@{wConfigPage::_sepchars()}){
         $found=1 if($t eq $sepchar);
       }
       $sepchar="" if(!$found);
    }
    if(!($type eq "simple" || $type eq "traditional") || !$sepchar){
       close($io);
       return "Command file seems to be corrupted - incorrect header";
    }
    $type= $type eq "simple" ? 1 : 0;
    ## read over $io for trivial problems (incorrect header, too long lines)
    while(<$io>){
        $line=$_; $lineno++;
        if( length($line) > 5000){
           close($io);
           return "Length of line $line in command file exceeds the allowed maximum";
        }
        next if(/^(\#|clear\s+macros|clear\s+constraints|macro\s+|constraint\s+enabled\s+|constraint\s+disabled\s+)/);
        last if(/^query /);
        close($io);
        return "Line $line in command file has incorrect header. Please correct it";
    }
    close($io);
    if($lineno > 5000){
        return "Number of lines in the command file exceeds the allowed maximum";
    }
    # reopen it
    if(!open($io,"<",$fh)){ return "Internal error, please try again"; }
    my $changed=0;
    if($session->getconf("type") != $type){
       $changed=1;
       $session->setconf("type",$type);
    }
    # set sepchar only if style=simple
    if($type && $session->getconf("sepchar") ne $sepchar){
       $changed=1;
       $session->setconf("sepchar",$sepchar);
    }
    if($changed){
       wUtils::write_user_config($session,$session->{config});
    }
    $line=<$io>; $lineno=1; # first line
    # other lines
    my $total="";
    while(<$io>){
       $lineno++; 
       ## clear all macros
       if(/^clear\s+macros/){
          use wDefault;
          wUtils::write_user_macros($session,wDefault::macros(),1);
          next;
       ## add a new macro
       } elsif(/^macro\s+(.*)$/){
          my $str=$1; $str =~ s/[\r\n\s]*$//;
          use wMacros;
          my $err=wMacros::add_macro($session,$str);
          if($err->{err}){ ## some error ...
             $total.=render_error($session,$lineno,"macro",$str,$err);
#             $total.="[Macro err: ".$err->{err}."]"; $waserr=1;
             last;
          }
          next;
       ## clear all constraints
       } elsif(/^clear\s+constraints/){
          wUtils::write_user_constraints($session,[],1);
          use wConstr;
          my $id_table=wConstr::adjust_id_table(
                wUtils::read_user_id_table($session),[]);
          wUtils::write_user_id_table($session,$id_table);
          next;
       ## add a new constraint
       } elsif(/^constraint\s+(en|dis)abled\s+(.*)$/){
          my $enabled=$1; my $str=$2; $str =~ s/[\r\n\s]*$//;
          use wConstr;
          my $err = wConstr::add_constraint($session,$str,$enabled eq "dis");
          if($err->{err}){ ## some error ...
             $total.=render_error($session,$lineno,"constraint ".$enabled."abled",$str,$err);
#             $total.="[Constr err: ".$err->{err}."]"; $waserr=1;
             last;
          }
          next;
       ## query
       } elsif(/^query\s+(.*)$/){
          my $str=$1; $str =~ s/[\r\n\s]*$//;
          use wExpr;
          my $err = wExpr::check_expr($session,$str);
          if($err->{res}==1){
             $total.=render_error($session,$lineno,"query",$str,$err);
#             $total.="[Query err: ".$err->{err}."]"; $waserr=1;
             last;
          }
          last;
       }
    }
    close($io);
    if(!$total){ $session->{actionvalue}="check"; }
    return $total;
}

1;


