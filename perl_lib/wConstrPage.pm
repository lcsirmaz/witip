####################
## wConstrPage.pm
####################
##
## Render constraints
##
###########################################################################
# This code is part of wITIP (a web based Information Theoretic Prover)
#
# Copyright (2017) Laszlo Csirmaz, Central European University, Budapest
# This program is free, open-source software. You may redistribute it
# and/or modify under the terms of the GNU General Public License (GPL).
# There is ABSOLUTELY NO WARRANTY, use at your own risk.
###########################################################################

package wConstrPage;

use wHtml;
use wUtils;
use strict; 
##############################################################
=pod

=head1 wITIP perl modules

=head2 wConstrPage.pm

Render and parse the constraints page.

=over 2

=item wConstrPage::Page($session)

Render the constraints page: banner, hidden delete buttons; the list of
constraints; and add new button.

Delete buttons: "delete marked", "cancel" "delete all" become visible when
one of the delete icons is clicked on.  It also sets bit 1 or bit 2 in the
javascript variable witipAllDisabled.  The same buttons with different title
("save changes" and "cancel") are used to submit the page when the set of
allowed (ticked) constraints changes.

List of constraints: each constraint occupies a single line starting with
two checkboxes: "delete" and "use" followed by the original (raw) text.  The
constraints are in a scrollable table which automatically scrolls to the
bottom.  Clicking on a text the raw text is copied to the editing part.

Constraint editing: "add constraint" is on the left followed by the edit
field.  The edit filed is actually two identical text areas on top of each
other.  The bottom one is slided down by two pixels and is used to show the
error position in case of syntactic error.  Keystrokes Up, Down, and Enter
are captured.  Up and Down gives the previous and following history entry;
Enter submits the edited string using an ajax request.  With no errors, the
ajax responders reloads the page.  The ajax responder sets / clears bit
three in javascript variable witipAllDisable.  Two additional lines in the 
editing box are reserved for error messages and auxiliary error text.

=item wConstrPage::Parse($session)

Process the page when submitted: delete and adjust enabled constraints.  If 
the edition line was not empty, save to the history.

=back

=cut
############################################################## 


sub render_constrline {
    my($session,$n,$label,$used,$text)=@_;
## HTML code:
## <tr class="conline-used/conline-unused" id="con_${n}_0">
##   <td class="conno"> $n </td>
##   <td class="condel"><div class="coninnerdel">
##      <checkbox name="condel_$label" id="condel_$n"
##           onchange="wi_conDelete(this)"></div></td>
##   <td class="conused"><div class="coninnerused">
##      <checkbox name="conused_$label" id="conused_$n"
##           onchange="wi_conUsedChanged(this)"></div></td>
##   <td class="context">
##      <div data-con="TEXT" class="innerctext" id="con_$n_1"
##          onclick="copyLinetoEdit(this)">TEXT</div></td>
    my $etext=wUtils::htmlescape($text);
    
    print "<tr class=\"conline-",($used?"":"un"),"used\" id=\"con_${n}_0\">\n";
    print "<td class=\"conno\">$n</td>\n";
    print "<td class=\"condel\" title=\"delete\"><div class=\"coninnerdel\">",
      "<input type=\"checkbox\" name=\"condel_$label\" id=\"condel_$n\"",
      " onchange=\"wi_conDelete(this);\">",
      "<label for=\"condel_$n\"></label></div></td>\n";
    print "<td class=\"conused\" title=\"use this constraint\">",
       "<div class=\"coninnerused\">",
       "<input type=\"checkbox\" name=\"conused_$label\" id=\"conused_$n\"",
       ($used ? " checked=\"checked\"" : ""),
       " onchange=\"wi_conUsedChanged(this);\">",
       "<label for=\"conused_$n\"></label></div></td>\n";
    print "<td class=\"context\"><div class=\"innerctext\"",
      " id=\"con_${n}_1\" style=\"font-family: ",$session->getconf("font"),";",
      " font-size: ",$session->getconf("fontsize"),"pt;\"",
      " title=\"click to edit\" data-con=\"$etext\"",
      " onclick=\"wi_copyLineToEdit(this);\">",
      $etext,"</div></td></tr>\n";
}

sub Page {
    my($session)=@_;
    my $img=$session->getconf("basehtml")."/images";
    my $tablesize=$session->getconf("tablesize")."px";
    my $inpcontent="";
    if($session->getpar("comingfrom") eq "constraints"){
        $inpcontent=$session->getpar("constr_input");
    }
    my $conlist=wUtils::read_user_constraints($session);
    my $ConstrUsed=""; # 0/1 sequence for used / not used
    foreach my $c(@$conlist){
        $ConstrUsed .= "," if($ConstrUsed ne "");
        $ConstrUsed .= ($c->{skip}?"0": "1");
    }
    # header
    wHtml::plain_header($session,"wITIP constraints", {
        lcss   => "constraint",
        style  => "
.coninnerdel label {background-image: url(\"$img/kuka.png\"); }
.coninnerdel input:checked + label {background-image: url(\"$img/kuka.png\"); background-position: -15px 0; }
.coninnerused label {background-image: url(\"$img/kuka.png\"); background-position: -30px 0; }
.coninnerused input:checked + label {background-image: url(\"$img/kuka.png\"); background-position: -45px 0; }
.concontainer { max-height: $tablesize; }
",
        javascript => "var witipConstrUsed=[$ConstrUsed];\n",
        banner => "constraints",
        ljs    => ["ConstrPage","History","Ajax",], ## "ConstrPage"
        bodyattr => "onload=\"wi_initPage();\"",
    });

    # spacer
    print "<div style=\" height: 5px\"> <!-- spacer --> </div>\n";

    # hidden: delete marked / cancel / delete all
## HTML code
## <div><table><tbody><tr>
##   <td><input submit delete marked onclick="wi_conDeleteMarked();"></td>
##   <td><input submit cancel onclick="wi_resetDel()"></td>
##   <td><input submit delete all onclick="wi_deleteAll()"></td>
## </tr></tbody></table></div>
    print "<div class=\"action\" id=\"delmarked\">",
       "<table><tbody><tr><td class=\"delsubmit\"><input type=\"submit\"",
       " name=\"deletemarked\" value=\"delete marked constraints\" id=\"id-deletemarked\"",
       " onclick=\"return wi_conDeleteMarked();\">",
       "</td>\n",
       "<td class=\"cancel\"><input type=\"submit\" title=\"cancel\" name=\"cancel\" value=\"cancel\"",
       " onclick=\"return wi_resetDel()\"></td>\n",
       "<td class=\"delall\"><input type=\"submit\" name=\"delall\"",
       " value=\"delete all constraints\" id=\"id-deleteall\" onclick=\"return wi_deleteAll()\"></td>\n",
       "</tr></tbody></table></div>\n";

    # the table of all constraints; this table can be empty
## HTML code
## <div><table><tbody>
##    <tr> ... constrline ... </tr>
## </tbody></table></div>
    my $ccont=0;
    print "<div class=\"concontainer\"><table class=\"constable\">",
      "<tbody id=\"id-contable\">";
    foreach my $c(@$conlist){
       $ccont++;
       render_constrline($session,$ccont,$c->{label},
           ($c->{skip}?0 : 1), $c->{raw});
    }
    if($ccont==0){
        my $style="<br><span style=\"padding-left: 2em; font-family: monospace;\">";
        print "<tr class=\"noconstryet\"><td>
        Checking validity of an entropy relation is done relative to a set of
        <i>constraints</i>. A constraint is one of the following:
        <ul><li>relation: two entropy expressions compared by one of
          =, &lt;=, or &gt;= </li>
          <li>functional dependency: the first variable list is determined by the
          second one: $style varlist1 : varlist2</span></li>
          <li>independence: the variable lists are totally independent;
              you can use either the first or the second syntax:$style
           varlist1  . varlist2  . varlist3  .  &#183;&#183;&#183;</span>$style
           varlist1 || varlist2 || varlist3 || &#183;&#183;&#183;</span></li>
          <li>Markov chain: the variable lists form a Markov chain;
               you can use either the first or the second syntax:$style
           varlist1  / varlist2  / varlist3  / &#183;&#183;&#183;</span>$style
           varlist1 -&gt; varlist2 -&gt; varlist3 -&gt; &#183;&#183;&#183;</span></li>
        </ul>
        </td></tr>\n";
    }
    print "</tbody></table></div>\n";

    # editing
## HTML code
## <div><table>tbody><tr>
##   <td><input submit onclick="wi_addConstraint(this)"></td>
##   <td>
##    <div><textarea const:input oninput="wi_autoreRize(this)"
##          onkeydown="keydown(event)">...</textarea>
##         <textarea const:shadow>----^</textarea></div>    
##    <div> Error message </div>
##    <div> auxiliary message </div>
##   </td>
## </tr></tbody></table></div>

    print "<div class=\"edit\">\n";
    print "<table><tbody><tr><td class=\"editsubmit\">";
    print "<input type=\"submit\" name=\"checkinput\" value=\"add constraint\"";
    print " onclick=\"return wi_addConstraint();\"";
    print " title=\"hit Enter to add the constraint\">";
    print "</td>\n";
    print "<td class=\"editline\">";
    print "<div class=\"dblinput\" id=\"iddblinput\">";
    print "<textarea class=\"inputmain\" id=\"constr_input\" name=\"constr_input\"",
      " oninput=\"wi_autoResize(this);\"",
      " style=\"font-family: ",$session->getconf("font"),
      "; font-size: ",$session->getconf("fontsize"),"pt;\"",
      " onkeydown=\"wi_editKey(event);\"",
      " autocomplete=\"off\" spellcheck=\"false\">$inpcontent</textarea>";
    print "<textarea class=\"inputshadow\" id=\"constr_shadow\" name=\"constr_shadow\"",
      " style=\"font-family: ",$session->getconf("font"),
      "; font-size: ",$session->getconf("fontsize"),"pt;\"",
      " autocomplete=\"off\"></textarea>";
    print "</div><!-- dblinput -->";
    print "<div class=\"errmsg\" id=\"constr_errmsg\"></div>\n";
    print "<div class=\"erraux\" id=\"constr_auxmsg\" style=\"font-family: ",$session->getconf("font"),
      "; font-size: ",$session->getconf("fontsize"),"pt;\"></div>";
    print "</td></tr></tbody></table>";
    print "</div><!-- edit -->\n";
        
    wHtml::html_tail();
}


sub Parse {
    my($session)=@_;
    return if($session->getpar("comingfrom") ne "constraints");
    # used and deleted constraints
    if(!$session->getpar("deletemarked") && !$session->getpar("delall")){
       # save editing line to history
       my $line=$session->getpar("constr_input");
       if($line !~ /^\s*$/ ){
           wUtils::write_user_history($session,"cons",$line);
       }
       return;
    }    
    # either delete OR change skipped addtribute, but not both
    my %used=(); my %killed=(); my ($useit,$saveit)=(1,0);
    foreach my $k(keys %{$session->{pars}}){
        $used{$1}=1 if($k =~ /^conused_(\d+)$/);
        if($k =~ /^condel_(\d+)$/){
            $killed{$1}=1; $useit=0;
        }
    }
    my $conlist=wUtils::read_user_constraints($session);
    my $newcon=[]; my $history=[];
    if($useit){ # nothing to delete; refresh the skip attribute
       foreach my $con( @$conlist){
           my $newskip=$used{$con->{label}}? 0 : 1;
           if($con->{skip} != $newskip){
               $con->{skip}= $newskip;
               $saveit=1; # there was a change
           }
           push @$newcon, $con;
       }
    } else { # delete
       foreach my $con( @$conlist){
           if($killed{$con->{label}}){
               push @$history, $con->{raw};
               $saveit=1; # there was a change
           } else {
               push @$newcon, $con;
           }
       }
    }
    if($saveit){
        wUtils::write_user_history($session,"cons",$history);
        wUtils::write_user_constraints($session,$newcon,1);
        use wConstr;
        my $id_table=wConstr::adjust_id_table(
             wUtils::read_user_id_table($session),$newcon);
        wUtils::write_user_id_table($session,$id_table);
        wUtils::set_modified($session);
    }
    return;
}

1;

