####################
## wMacrosPage.pm
####################
##
## Add, delete, edit, list macros
##
###########################################################################
# This code is part of wITIP (a web based Information Theoretic Prover)
#
# Copyright (2017) Laszlo Csirmaz, Central European University, Budapest
# This program is free, open-source software. You may redistribute it
# and/or modify under the terms of the GNU General Public License (GPL).
# There is ABSOLUTELY NO WARRANTY, use at your own risk.
###########################################################################

package wMacrosPage;

use wHtml;
use wUtils;
use strict;

#######################################################
=pod

=head1 wITIP perl modules

=head2 wMacrosPage.pm

Render and process the macro page.

=over 2

=item wMacrosPage::Page($session)

Render the main macros page: banner; hidden delete buttons; list of macros; 
and add a new macro.

Delete buttons: "delete marked macros", "cancel", "delete all macros".  They
are shown only when one of the "delete" icons in the macro list are clicked. 
It sets bit 1 in the javascript variable witipAllDisabled to prevent any other
action.

List of macros: each macro occupies a single line.  Macros are listed in
alphanumeric order, then by parameter number.  Lines in the macro list have
a (hidden) label; "delete" checkbox; and the macro's raw (original) text and
its unrolled internal form.  The macros are in a scrollable table which
automatically scrolls to the bottom.  Clicking on a macro text copies the
raw text to the editing part, and presents the internal (unrolled) form in
the aux line.

Macro editing: The "add macro" button is on the left followed by the edit
field.  This field is actually two text areas on top of each other.  The top
one has transparent background, and the bottom one is slided down by two
pixels and is used to show the error position.  The content of the bottom
area is erased after any keystroke in the editing field.  Keystrokes Up,
Down, and Enter are captured.  Up and Down gives the previous and following
history entry; Enter submits the given string using an ajax request -- this
is equivalent to pushing the "add macro" button.  With no errors, the ajax
responder reloads the page with the new set of macros and history.  Until
the response to the ajax request arrives, bit 2 of the javascript variable
witipAllDisabled is set to prevent firing further requests.  Two additional
lines in the macro editing box are reserved for error messages and auxiliary
error text.

The history (Up and Down keys) works as follows.  The History[] javascript
array is requested by an ajax request just after the page loaded; until it
arrives, Up and Down arrows are disabled.  Pressing any key except for Up
and Down sets the history pointer to zero.  When the Up key is pressed, the
pointer is increased by one, and the content of History[pointer] is copied
to the editing field.  When the pointer is initially zero, the content of
the editing field is copied first to History[0].  The Down key does nothing
if the pointer is zero, otherwise decreases the pointer and copies
History[pointer] to the editing field.  When a macro text is copied to the
editing field (by clicking on a macro text) and the history pointer is zero,
the original content of the editing field is copied to History[0], and the
pointer is set to 1 (so pressing Down immediately retrieves the original
content).

=item wMacrosPage::Parse($session)

Process the request submitted by the macro page.  Either delete marked
macros, as instructed.  Otherwise, if not empty, save the editing line to
history.

=back

=cut
#######################################################

sub render_macroline {
    my($session,$n,$label,$text,$unrolled)=@_;
## HTML code:
## <tr class="macroline" id="mac:$n:0">
##   <td class="macrono"> $n </td>
##   <td class="macrodel"><div class="innermdel">
##     <checkbox name="mdel:$label" id="mdel:$n"
##          onchange="wi_macroDel(this)"></div></td>
##   <td class="macrotext">
##     <div data-macro="TEXT" id="mac:$n:1"
##          onclick="wi_copyLineToEdit(this)">TEXT</div></td>
## </tr>
    my $etext=wUtils::htmlescape($text);
    print "<tr class=\"macroline\" id=\"mac_${n}_0\">\n";
    print "<td class=\"macrono\">$n</td>\n";
    print "<td class=\"macrodel\" title=\"delete\"><div class=\"innermdel\">",
       "<input type=\"checkbox\" name=\"mdel_$label\" id=\"mdel_$n\"",
       " onchange=\"wi_macroDel(this);\" title=\"delete\">",
       "<label for=\"mdel_$n\"></label></div></td>\n";
    print "<td class=\"macrotext\"><div class=\"innermtext\" ",
       "id=\"mac_${n}_1\" style=\"font-family: ", $session->getconf("font"),
       "; font-size: ",$session->getconf("fontsize"),"pt;\"" ,
       " title=\"click to edit\" data-macro=\"$etext\"",
       " data-unrolled=\"",wUtils::htmlescape($unrolled),"\"",
       " onclick=\"wi_copyLineToEdit(this);\">",
       $etext,"</div></td></tr>\n";
}

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

sub Page {
    my($session)=@_;
    # background images with configurable URI's
    my $img=$session->getconf("basehtml")."/images";
    my $tablesize=$session->getconf("tablesize")."px";
    ## these values are valid only when coming this page
    my $inpcontent="";
    if($session->getpar("comingfrom") eq "macros"){
        $inpcontent= $session->getpar("macro_input");
    }
    # header
    wHtml::plain_header($session,"wITIP macros", {
        lcss    => "macros",
        style   => "
.innermdel label {background-image: url(\"$img/kuka.png\"); }
.innermdel input:checked + label { background-image: url(\"$img/kuka.png\"); background-position: -15px 0; }
.macrocontainer { max-height: $tablesize; }
",
        banner  => "macros",
        ljs     => ["MacroPage","History","Ajax"],
        bodyattr => "onload=\"wi_initPage();\"",
    });

    # spacer
    print "<div style=\"height: 5px\"> <!-- spacer --> </div>\n";

    # hidden: delete marked / cancel / delete all  buttons
## HTML code
## <div><table><tbody><tr>
##   <td><input submit delete marked></td>
##   <td><input submit cancel onclick="wi_resetDel()"></td>
##   <td><input submit delete all onclick="wi_deleteAll()"></td>
## </tr></tbody></table></div>
    print "<div class=\"action\" id=\"delmarked\">",
       "<table><tbody><tr><td class=\"delsubmit\"><input type=\"submit\"",
       " name=\"deletemarked\" value=\"delete marked macros\"",
       " onclick=\"return wi_deleteMarkedMacros();\">",
       "</td>\n",
       "<td class=\"cancel\"><input type=\"submit\" name=\"cancel\" value=\"cancel\"",
       " onclick=\"return wi_resetDel()\"></td>\n",
       "<td class=\"delall\"><input type=\"submit\" name=\"delall\"",
       " value=\"delete all macros\" onclick=\"return wi_deleteAll();\"></td>\n",
       "</tr></tbody></table></div>\n";
    # the table of macros; this table can be empty
## HTML code
## <div><table><tbody>
##    <tr>...macroline...</tr>
## </tbody></table></div>
    use wParser;
    my $parser= new wParser($session);

    print "<div class=\"macrocontainer\"><table class=\"macros\">",
          "<tbody id=\"macrotable\">\n";
    my $macrocnt=0;
    my $macrolist=wUtils::read_user_macros($session);
    foreach my $macro ( sort {_cmpmacros($a,$b)} @$macrolist ){
        next if($macro->{std});
        $macrocnt++;
        render_macroline($session,$macrocnt,$macro->{label},
            $macro->{raw},$parser->print_macro($macro));
    }
    if($macrocnt==0){
        my $ex="D(X;Y}Z) = I(X;Y|Z)+I(X;Z|Y)+I(Y;Z|X)" ;
        my $invoke="D(A,B; X,Y | A,B,C,D,X,Y)";
        if($session->getconf("style")){
            my $sepchar=$session->getconf("sepchar");
            $ex="D(a,b|c) = I(a,b|c)+I(a,c|b)+I(c,b|a)";
            $invoke="D(ab, xy | abcdxy)";
            $ex =~ s/,/$sepchar/ge;
            $invoke =~ s/,/$sepchar/ge;
        }      
        print "<tr class=\"nomacroyet\"><td> Define macros (shorthands for entropy
        expressions) here.<br>
        A macro definition starts with the macro name: an upper case letter, followed by
        the argument list enclosed in parentheses, an = sign, and then the macro text (which
        can use previusly defined macros), like this one:<br>
        <span style=\"font-family: monospace; padding-left: 2em;\">$ex</span><br>
        To invoke the macro, use variable lists as arguments like this one:<br>
        <span style=\"font-family: monospace; padding-left: 2em;\">$invoke</span><br>
        Either the list separator or the pipe character (vertical bar) can separate the
        arguments, but the definition and the usage must be consistent.
        </td></tr>\n";
    }
    print "</tbody></table></div>\n";

    # editing 
## HTML code
## <div><table>tbody><tr>
##   <td><input submit onclick="wi_addMacro(this)"></td>
##   <td>
##    <div><textarea macro_input oninput="wi_autoResize(this)"
##          onkeydown="keydown(event)">...</textarea>
##         <textarea macro_shadow>----^</textarea></div>    
##    <div> Error message </div>
##    <div> auxiliary message </div>
##   </td>
## </tr></tbody></table></div>

    print "<div class=\"edit\">\n";
    print "<table><tbody><tr><td class=\"editsubmit\">";
    print "<input type=\"submit\" name=\"checkinput\" value=\"add a macro\"";
    print " onclick=\"return wi_addMacro();\"";
    print " title=\"hit Enter to add the macro\">";
    print "</td>\n";
    print "<td class=\"editline\">";
    print "<div class=\"dblinput\" id=\"iddblinput\">";
    print "<textarea class=\"inputmain\" id=\"macro_input\" name=\"macro_input\"",
      " oninput=\"wi_autoResize(this);\"",
      " style=\"font-family: ",$session->getconf("font"),
      "; font-size: ",$session->getconf("fontsize"),"pt;\"",
      " onkeydown=\"wi_editKey(event);\"",
      " autocomplete=\"off\" spellcheck=\"false\">$inpcontent</textarea>";
    print "<textarea class=\"inputshadow\" id=\"macro_shadow\" name=\"macro_shadow\"",
      " style=\"font-family: ",$session->getconf("font"),
      "; font-size: ",$session->getconf("fontsize"),"pt;\"",
      " autocomplete=\"off\"></textarea>";
    print "</div><!-- dblinput -->";
    print "<div class=\"errmsg\" id=\"macro_errmsg\"></div>\n";
    print "<div class=\"erraux\" id=\"macro_auxmsg\" style=\"font-family: ",$session->getconf("font"),
      "; font-size: ",$session->getconf("fontsize"),"pt;\">";
    print "</div>";
    print "</td></tr></tbody></table>";
    print "</div><!-- edit -->\n";
        
    wHtml::html_tail();
}

##
sub Parse {
    my($session)=@_;
    return if($session->getpar("comingfrom") ne "macros");
    if(!$session->getpar("delall") && !$session->getpar("deletemarked")){
       # save editing line to history
       my $line=$session->getpar("macro_input");
       if($line !~ /^\s*$/ ){
           wUtils::write_user_history($session,"macro",$line);
       }
       return;
    }
    my %labels=();
    foreach my $k(keys %{$session->{pars}}){
       $labels{$1}=1 if($k =~ /^mdel_(\d+)$/);
    }
    my $macrolist=wUtils::read_user_macros($session);
    my $newmacros=[]; my $history=[];
    foreach my $macro ( sort {_cmpmacros($a,$b)} @$macrolist ){
        if(!$macro->{std} && $labels{$macro->{label}}){
            push @$history, $macro->{raw};
        } else {
            push @$newmacros,$macro;
        }
    }
    if(scalar @$history>0){ # there are changes
        wUtils::write_user_macros($session,$newmacros,1);
        wUtils::set_modified($session);
    } # clean up history in any case
    wUtils::write_user_history($session,"macro",$history);
    return;

}

1;

