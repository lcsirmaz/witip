##################
## wMainPage.pm
##################
##
## render the main page
##
###########################################################################
# This code is part of wITIP (a web based Information Theoretic Prover)
#
# Copyright (2017) Laszlo Csirmaz, Central European University, Budapest
# This program is free, open-source software. You may redistribute it
# and/or modify under the terms of the GNU General Public License (GPL).
# There is ABSOLUTELY NO WARRANTY, use at your own risk.
###########################################################################

package wMainPage;

use wHtml;
use wUtils;
use strict;

############################################################
=pod

=head1 wMainPage.pm

=over 2

=item wMainPage::Page($session)

Render the main wITIP page: banner; hidden list of prototypes (used by the
ajax responder to insert new lines to the request table); usually hidden
buttons when lines are to be deleted; the list of recent requests (history);
and where new queries can be entered.

In the result table  each query occupies one or two lines showing the trash
box, the result indicator, whether constraints were used or not, and the
query.  In case of "unroll" query the next line contains the result.

There are two buttons in the query submission part: check with or without
constraints.  Clicking on one of them makes it the default (the other
is dimmed).

The query editing field is actually two text areas on top of each other. 
The bottom one is slided down by two pixels and is used to show the error
position.  Keystrokes Up, Down and Enter are captured.  Up, Down gives the
previous and following entry in the list; Enter submits the given string
using an ajax request - equivalent to pressing the actual submission button. 
With no errors, the ajax responder inserts the query at the end of the
result table.  Periodic ajax requests are sent to check for pending
requests.

=item $result=wMainPage::parse_expr_history($session,$update)

Read and parse the history file. Each line in the history
file has the following format:

    <type>,<label>,<standalone>,<text>

where type, label, standalone are integers (or empty), and text is the query
(and the urolled result if applicable).  If $update is set, then the
procedure checks pending requires and modifies the entries accordingly.

The $result is a hash with three fields: {pending}, {hist}, and {edit}. 
Both {pending} and {hist} are array references (the array can be empty); and
{edit} is a single string contenaining the last content of the editing
field.  {Pending} is the array of labels of pending requests; entries in
{hist} are four-element arrays of the form [ type, label, standalone, text
].  When $update is not defined, the history list is truncated to the size
specified in wDefaults.

=item wMainPage::Parse($session)

Saves the content of the editing field, if not empty, so that next time
it can be restored. It also handles all delete requests: reconstructs
the history file complete with finished pending requests.

=back

=cut
############################################################
# parse history file
# returns a hash with three fields:
#    hist    => [ [type,label,standalone,text], ... ],
#    pending => [ label, ... ],
#    edit    => "string"
#
sub parse_expr_history {
    my($session,$update)=@_;
    my $limit=$session->getconf("histsize");
    my $n=0; my $i=0;
    my @hist=(); my %pending=(); my $edit=""; my $last="";
    my $fh;
    if(open($fh, "<",$session->{stub}.$session->getconf("exthis"."expr"))){
      while(<$fh>){
        chomp;
        next if($_ =~ /^$/ || $_ eq $last);
        $last=$_;
        my ($type,$label,$sta,$txt)= $last =~ m#^(\d+),(\d+),(\d*),(.*)$# ;
        chomp $txt; $txt =~ s/\s+$//;
        if($type==99){ # edit
            $edit=$txt;
        } elsif($sta eq "2"){ # follow-up result
            $hist[$pending{$label}]->[0]=$type if( $pending{$label}< scalar @hist);
            delete $pending{$label};
        } else { # new query
            if($type==3){
                $pending{$label} = 0+ scalar @hist;
            }
            push @hist, [$type,$label,$sta,$txt];
            $edit="";
        }
      }
      close($fh);
    }
    if($update){ # check pending requests
        use wExpr;
        foreach my $k(keys %pending){
          my($res,$txt)=wExpr::check_result($session,$k);
          # updated if($txt ne ""); $res is 4..9
          next if($txt eq "");
          $hist[$pending{$k}]->[0]=$res;
          delete $pending{$k};
        }
    }
    my @pa = sort { $a <=> $b } keys %pending;
    my $excess= scalar @hist - $session->getconf("histsize");
    if(!$update && $excess>0){ @hist = splice(@hist,0,$excess); }
    return {
        hist    => \@hist,
        pending => \@pa,
        edit    => $edit,
    };
}

# render delete checkbox
## HTML code:
##    <checkbox name="resdel_label" id="resdel_count" onchange="wi_resDelete(this)">
##    <label for=resdel_count"></label>
sub _render_delete_checkbox {
    my($id,$label)=@_;
    my $name="";
    $name=" name=\"resdel_$label\"" if($label);
    return "<input type=\"checkbox\"$name onchange=\"wi_resDelete(this);\"".
      " value=\"1\"".
      " id=\"".($id =~ m#^proto_# ? $id : "resdel_$id") ."\">";
}

# render the result type
#  $id = <code> or $id = proto_<code> or $id= <code>_<idlabel>
#    where <code> is one of waiting|timeout|failed|true|false|onlyge|onlyle|zap
## HTML code:
##  <span id="idlabel"> TEXT </span>
sub _render_result_type {
    my($session,$id)=@_;
    my $label="";
    if($id =~ s/^proto_//){ $label=" id=\"proto_$id\""; }
    elsif( $id =~ s/_(.+)$//){ $label=" id=\"$1\""; }
    if($id eq "waiting"){
        my $img=$session->getconf("basehtml")."/images/waiting.gif";
        return "<span$label><img class=\"rescodeimg\" src=\"$img\" alt=\"waiting\"></span>";
    } elsif($id eq "timeout"){
        return "<span$label class=\"timeout\">time</span>";
    } elsif($id eq "failed"){
        return "<span$label class=\"failed\">failed</span>";
    } elsif($id eq "true"){
        return "<span$label class=\"true\">true</span>";
    } elsif($id eq "false"){
        return "<span$label class=\"false\">false</span>";
    } elsif($id eq "onlyge"){
        return "<span$label class=\"onlyge\">only<span class=\"onlyspacer\"></span>&ge;</span>";
    } elsif($id eq "onlyle"){
        return "<span$label class=\"onlyle\">only<span class=\"onlyspacer\"></span>&le;</span>";
    } elsif($id eq "zap"){
        return "<span$label class=\"zap\"> </span>";
    }
    print STDERR "wMainPage::render_result_type: unknown proto id $id";
    return "result_type: unknown id $id";
}
# render the constraint type
#  $id = <code> or $id = proto_<code>
#    where <code> is either constr or noconstr
## HTML code:
##  <span id="idlabel"> TEXT </span>
sub _render_result_constr {
    my($id)=@_;
    my $label="";
    if($id =~ s/^proto_//){ $label=" id=\"proto_$id\""; }
    if($id eq "constr"){
        return "<span$label class=\"wconstr\">C</span>";
    } elsif($id eq "noconstr"){
        return "<span$label class=\"wnoconstr\"></span>";
    }
    print STDERR "wMainPage::render_result_constr: unknown proto id $id\n";
    return "Unknown proto id $id";
}
# render result code
#   $id = <code> or $id = proto_<code>
#    where <code> is either code or auxcode
## HTML code:
##  <div class="id"  id="idlabel"> TEXT </span>
sub _render_result_code {
    my($session,$id,$text,$history)=@_;
    my $label="";
    my $escapedtext=wUtils::htmlescape($text);
    if($id =~ s/^proto_//){ $label=" id=\"proto_$id\""; }
    elsif( $id =~ s/_(.+)$//){ $label=" id=\"$1\""; }
    return "<div class=\"$id\"$label" .
      " style=\"font-family: ". $session->getconf("font") .
      "; font-size: ". $session->getconf("fontsize") ."pt;\"" .
      ($id eq "code" ? 
          " title=\"click to edit\" onclick=\"copyLineToEdit(this);\"".
          " data-expr=\"$escapedtext\""
          : "").
      (defined($history) ?" id=\"histID_$history\"" : "" ).
      ">$escapedtext</div>";
}

# render the result line
sub render_resultline {
    my($session,$label,$type,$standalone,$query,$history)=@_;
# label:  the ID of the line
# type:   result type
# constr: 0 - without constraints, 1 - with constraints
# query:  either code, or code++auxmsg
## HTML code:
## <tr class="resultline id="res_LABEL_0">
##    <td class="resdel"><div class="resinnerdel">
##       CHECKBOX<label for="resdel_LABEL"></label></div></td>
##    <td class="rescode" id="res_LABEL_1"> result_type() </td>
##    <td class="constraint"> result_constr()</td>
##    <td class="query1"> result_code( "code" ) </td>
## </tr>
## <tr class="auxline">
##    <td class="skip"></td>
##    <td class="skip"></td>
##    <td class="query2"> result_code("auxcode") </td>
## </tr>
    print "<tr class=\"resultline\" id=\"res_${label}_0\">\n";
    # delete
    print "<td class=\"resdel\"><div class=\"resinnerdel\">",
      _render_delete_checkbox($history,$label),
      "<label for=\"resdel_$history\"></label></div></td>\n";
    # type
    print "<td class=\"rescode\" id=\"res_${label}_1\">",
        _render_result_type($session,$type),"</td>\n";
    # constraints
    print "<td class=\"constraint\">",
        _render_result_constr($standalone ? "noconstr" : "constr"),"</td>\n";
    # code
    my $aux=""; if($query =~ s/\+\+\+(.*)$//){ $aux=$1; }
    print "<td class=\"query1\">",
        _render_result_code($session,"code",$query,$history),"</td>\n";
    print "</tr>\n";
    return if($aux eq "");
    # aux line
    print "<tr class=\"auxline\"><td class=\"skip\"> </td><td class=\"skip\"> </td>\n",
        "  <td class=\"skip\"></td>\n<td class=\"query2\">",
        _render_result_code($session,"auxcode",$aux),"</td>\n";
    print "</tr>\n";
}

sub Page {
    my($session)=@_;
    my $tablesize=$session->getconf("tablesize")."px";
    my $img=$session->getconf("basehtml")."/images";
    my $hist=parse_expr_history($session);
    wHtml::plain_header($session,"wITIP", {
       lcss   =>"main",
       banner =>"check",
       ljs => ["MainPage","Ajax"],
       bodyattr => "onload=\"wi_initPage();\"",
       style => "
.resinnerdel label {background-image: url(\"$img/kuka.png\"); }
.resinnerdel input:checked + label {background-image: url(\"$img/kuka.png\"); background-position: -15px 0; }
.rescontainer { max-height: $tablesize; }
",
       javascript => "var wi_pendingLabels=[".join(',',@{$hist->{pending}})."];
",
    });
    #spacer
    print "<div style=\"height: 5px;\"> <!-- spacer --> </div>\n";
    # prototypes
    print "<div style=\"display: none\"><!-- prototype -->\n";
    print _render_delete_checkbox("proto_delete"),"\n";
    foreach my $tag (qw(waiting timeout failed true false onlyge onlyle zap )){
        print _render_result_type($session,"proto_$tag"),"\n";
    }
    print _render_result_constr("proto_constr"),"\n";
    print _render_result_constr("proto_noconstr"),"\n";
    print _render_result_code($session,"proto_code"),"\n";
    print _render_result_code($session,"proto_auxcode"),"\n";
    print "</div>\n";
    # hidden: delete marked / cancel / delete all
## HTML code
## <div><table><tbody><tr>
##   <td><input submit delete marked></td>
##   <td><input submit cancel onclick="wi_resetDel()"></td>
##   <td><input submit delete all onclick="wi_deleteAll()"></td>
## </tr></tbody></table></div>
    print "<div class=\"action\" id=\"delmarked\" style=\"visibility: hidden;\">",
       "<table><tbody><tr><td class=\"delsubmit\"><input type=\"submit\"",
       " name=\"deletemarked\" value=\"delete marked lines\" id=\"id-deletemarked\"",
       " onclick=\"return wi_deleteMarkedLines();\">",
       "</td>\n",
       "<td class=\"cancel\"><input type=\"submit\" name=\"cancel\" value=\"cancel\"",
       " onclick=\"return wi_resetDel()\"></td>\n",
       "<td class=\"delall\"><input type=\"submit\" name=\"delall\"",
       " value=\"delete all lines\" id=\"id-deleteall\" onclick=\"return wi_deleteAll()\"></td>\n",
       "</tr></tbody></table></div>\n";

    # result table, this table can be empty
## HTML CODE
## <div class="rescontainer"><table class="result"><tbody id="resulttable">
##   <tr> ... resultlines </tr>
## </tbody></table></div>
    print "<div class=\"rescontainer\"><table class=\"result\">",
          "<tbody id=\"resulttable\">\n";
    my $cnt=0;
    my $types = [ "zap", "zap", "zap","waiting","timeout","failed",
                  "true","false","onlyge","onlyle" ];
    my $tablelines = parse_expr_history($session);
    foreach my $line(@{$hist->{hist}}){
       $cnt++;
       render_resultline($session,$line->[1], # label
              $types->[$line->[0]],           # type
              $line->[2],                     # standalone
              $line->[3],                     # text
              $cnt);                          # count
    }
    if($cnt==0){
        print "<tr class=\"nocontent\"><td class=\"resdel\"> </td><td class=\"rescode\"> &nbsp; </td>\n",
          "<td class=\"constraint\"> &nbsp; </td> <td class=\"welcome\">Welcome to wITIP.<br><br>
          Use the menu at the top (from left to right) to get help; configure wITIP;
          add or edit your macros and constraints; check entropy expressions; or change 
          your session.<br>
          Enter a query in the box below to check it for validity
          with or without the specified constraints.<br>
          Clicking on &quot;check&quot; or just pressing the Enter key checks the
          validity with all enabled constraints. Clicking on &quot;no
          constraints&quot; checks the query without the constraints &ndash; and also
          changes what pressing Enter does.<br>
          Use the Up and Down keys to reach earlier queries, or just click on the result line.
          </td></tr>\n";
    }
    print "</tbody></table></div>\n";
    #editing
## HTML CODE
## <div><table>tbody><tr>
##  <td>
##     <div class=\"chkwith\"><input submit onclick="submit(1);"></div>
##     <div class=\"chkwithout"><input submit onclick="submit(0);"></div>
##  </td>
##  <td>
##    <div><textarea expr_input oninput="wi_autoResize(this)"
##          onkeydown="keydown(event)">...</textarea>
##         <textarea expr_shadow>----^</textarea></div>    
##    <div> Error message </div>
##    <div> auxiliary message </div>
##  </td>
## </tr></tbody></table></div>
    print "<div class=\"edit\">\n";
    print "<table><tbody><tr><td class=\"editsubmit\">";
    print "<div class=\"chkwith\"><input type=\"submit\"",
       " name=\"checkinput-constraints\" class=\"defaultcheckbutton\"",
       " id=\"id-chkwith\" value=\"check\" onclick=\"return wi_checkInput(1);\"",
       " title=\"check expression with constraints\"></div>\n";
    print "<div class=\"chkwithout\"><input type=\"submit\"",
       " name=\"checkinput-noconstraints\" class=\"auxcheckbutton\"",
       " id=\"id-chkwithout\" value=\"no&nbsp;constraints\" onclick=\"return wi_checkInput(0);\"",
       " title=\"check expression without specified constraints\"></div>";
    print "</td>\n";
    print "<td class=\"editline\">";
    print "<div class=\"dblinput\" id=\"iddblinput\">";
    print "<textarea class=\"inputmain\" id=\"expr_input\" name=\"expr_input\"",
      " oninput=\"wi_autoResize(this);\"",
      " style=\"font-family: ",$session->getconf("font"),
      "; font-size: ",$session->getconf("fontsize"),"pt;\"",
      " onkeydown=\"wi_editKey(event);\"",
      " autocomplete=\"off\" spellcheck=\"false\">",
      wUtils::htmlescape($hist->{edit}),
      "</textarea>";
    print "<textarea class=\"inputshadow\" id=\"expr_shadow\" name=\"expr_shadow\"",
      " style=\"font-family: ",$session->getconf("font"),
      "; font-size: ",$session->getconf("fontsize"),"pt;\"",
      " autocomplete=\"off\"></textarea>";
    print "</div><!-- dblinput -->";
    print "<div class=\"errmsg\" id=\"expr_errmsg\"></div>\n";
    print "<div class=\"erraux\" id=\"expr_auxmsg\" style=\"font-family: ",$session->getconf("font"),
      "; font-size: ",$session->getconf("fontsize"),"pt;\">";
    print "</div>";
    print "</td></tr></tbody></table>";
    print "</div><!-- edit -->\n";
        
    wHtml::html_tail();
}

sub Parse {
    my($session)=@_;
    return if($session->getpar("comingfrom") ne "check");
    if(!$session->getpar("delall") && !$session->getpar("deletemarked")){
        my $text=$session->getpar('expr_input');
        if($text){
           wUtils::write_user_history($session,"expr","99,0,2,$text");
        }
    }
    my %labels=();
    foreach my $k(keys %{$session->{pars}}){
        $labels{$1}=1 if($k =~ /^resdel_(\d+)$/);
    }
    my $expr=parse_expr_history($session,1);
    # if still pending, don't delete
    foreach my $k ( @{$expr->{pending}} ){
        delete $labels{$k};
    }
    my @newhist=();
    foreach my $line (@{$expr->{hist}}){
        next if($labels{$line->[1]});
        push @newhist, $line;
    }
    if($session->getpar('expr_input')){
        push @newhist, [99,0,2,$session->getpar('expr_input')];
    }
    wUtils::replace_expr_history($session,\@newhist);
    return;
}


1;

