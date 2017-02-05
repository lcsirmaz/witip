####################
## wConfigPage.pm
####################
##
## render user configuration
##
###########################################################################
# This code is part of wITIP (a web based Information Theoretic Prover)
#
# Copyright (2017) Laszlo Csirmaz, Central European University, Budapest
# This program is free, open-source software. You may redistribute it
# and/or modify under the terms of the GNU General Public License (GPL).
# There is ABSOLUTELY NO WARRANTY, use at your own risk.
###########################################################################

package wConfigPage;

use wHtml;
use wUtils;
use strict;

######################################################
=pod

=head1 wConfigPage.pm

Render user configuration page

=over 2

=item wConfigPage::Page($session)

Render the user configuration page.

=item $config = wConfigPage::Parse($session)

Parse the result of Page() and return the hash with the newly defined
values. All fields in $config are valid as the rendering uses checkbox,
radiobox, and selection only.

=back

=head2 Values to chose from

Local routines _fontfamily(), _fontsize(), _tablesize(), _history(),
_sepchars(), and _timeout() define the values which can be chosen from. 
Only equal width (monospace) familes are used which allows an easy
indication of the error position.  The default font family is "monospace,
monospace".


=cut
######################################################
# selection items; value,   text
sub _fontfamily { return [
        "monospace, monospace",        "default",
        "Andale Mono, monospace",      "Andale Mono",
        "Courier New, monospace",      "Courier New",
        "Courier, monospace",          "Courier",
        "DejaVu Sans Mono, monospace", "DejaVu",
        "FreeMono, monospace",         "FreeMono",
        "Lucida Console, monospace",   "Lucida",
]; }
sub _fontsize { return  [
        8,            8,
        9,            9,
        10,           10,
        11,           11,
        12,           12,
        13,           13,
        14,           14,
        17,           17,
]; }
sub _tablesize { return [
        300,          15,
        360,          18,
        400,          20,
        500,          25,
        600,          30,
        800,          40,
       1000,          50,
]; }
sub _sepchars { return [
        "comma",     ',',
        "semicolon", ';',
        "colon",     ':',
        "point",     '.',
        "caret",     '^',
        "hashmark",  '#',
]; }
sub _timeout { return [
        1,            "&nbsp;1 sec",
        2,            "&nbsp;2 sec",
        3,            "&nbsp;3 sec",
        5,            "&nbsp;5 sec",
        10,           "10 sec",
        15,           "15 sec",
        20,           "20 sec",
        30,           "30 sec",
        60,           "&nbsp;1 min",
        120,          "&nbsp;2 min",
        300,          "&nbsp;5 min",
        600,          "10 min",
]; }

# render a <select> ... </select> item
sub _select {
    my($arr,$default,$name,$extra)=@_;
    print "<select name=\"$name\" ",($extra||""),">\n";
    for (my $i=0;$i<scalar @$arr; $i+=2){
        print "<option value=\"",$arr->[$i];
        print "\" selected=\"selected" if($default eq $arr->[$i]);
        print "\">",$arr->[$i+1],"</option>\n";
    }
    print "</select>";
}
# render a <checkbox> item
sub _checkbox {
    my($default,$name)=@_;
    print "<input type=\"checkbox\" name=\"$name\" value=\"1\"";
    print " onchange=\"wi_showButtons();\"";
    print " checked=\"checked\"" if($default);
    print ">";
}
# generate the page
sub Page {
    my($session)=@_;
    wHtml::plain_header($session,"wITIP config", {
        bodyattr =>"onload=\"wi_showSampletext();\"",
        lcss     =>"config",
        banner   =>"config",
        javascript => "
function gid(id){ return document.getElementById(id); }
function wi_showButtons(){
    witipAllDisabled=1;
    gid('savebuttons').style.visibility='visible';
}
function wi_showSampletext(){
    var font=gid('settingfont');
    var sample=gid('sampletext');
    sample.style['font-family']=font.value;
    sample.style['font-size']=gid('settingsize').value + 'pt';
}
function wi_showSample(){
    wi_showButtons(); wi_showSampletext();
}",
    });
    print <<FORM;
<div style="height: 5px;"> <!-- spacer --> </div>
<div class="action" id=\"savebuttons\">
  <table><tbody><tr>
    <td class="save"><input type="submit" name="save" value="save"></td>
    <td class="cancel"><input type="submit" name="reset" value="discard changes"></td>
  </tr></tbody></table>
</div>
<div class="config"><table class="conftable"><tbody>
  <tr class="subt"><td class="firstcol"> </td><th class="secondcol">Appearence</th></tr>
  <tr style="vertical-align: baseline;"><td class="inp">
FORM
    # selecting font family
    _select(_fontfamily(),$session->getconf("font"),"settingfont",
         "id=\"settingfont\" onchange=\"wi_showSample();\"");
    my $istyle="font-family: ".$session->getconf("font") . 
         "; font-size: ". $session->getconf("fontsize") . "pt";
    print <<SELECTFONT;
</td>
<td> Font family &nbsp; &nbsp; Sample text:
   <span id="sampletext" style="$istyle;">
     The quick brown fox jumps over the lazy dog</span></td></tr>
   <tr><td class="inp">
SELECTFONT
    #selecting font size
    _select(_fontsize(),$session->getconf("fontsize"),"fontsize",
         "id=\"settingsize\" onchange=\"wi_showSample();\"");
    print "</td><td> Font size </td></tr>\n";
    # table size
    print "<tr><td class=\"inp\">";
    _select(_tablesize(),$session->getconf("tablesize"),"tablesize",
         "onchange=\"wi_showButtons()\"");
    print "</td><td>Table height</td></tr>\n";
    # all macro args must be used
    print "<tr class=\"subt\"><td> </td><th> Macro definition </th></tr>\n";
    print "<tr><td class=\"inp\">";
    _checkbox($session->getconf("macroarg"),"macroarg");
    print "</td>\n";
    print "<td> Complain if a macro argument is not used in the definition </td></tr>\n";
    # Syntax
    print "<tr class=\"subt\"><td> </td><th>Syntax</th></tr>\n";
    ##  style
    print "<tr><td class=\"inp\">";
    _checkbox($session->getconf("style"),"simplesyntax");
    print "</td>\n";
    print "<td> Use simplified sytax </td></tr>\n";
    ##  use ()
    print "<tr><td class=\"inp\">";
    _checkbox($session->getconf("parent"),"parent");
    print "</td>\n";
    print "<td> Grouping by parentheses ( ) <span style=\"color:#909090\">(not recommended)</span></td></tr>\n";
    ##  use {}
    print "<tr><td class=\"inp\">";
    _checkbox($session->getconf("braces"),"braces");
    print "</td>\n";
    print "<td> Grouping by braces { }</td></tr>\n";
    ##  prime(s) at the end of variables
    print "<tr><td class=\"inp\">";
    _checkbox($session->getconf("varprime"),"varprime");
    print "</td>\n";
    print "<td> Variables can have prime(s) at the end: <span class=\"tt\">a\'</span></td></tr>\n";
    # Simple style syntax
    print "<tr class=\"subt\"><td></td><th>Simplified syntax details</th></tr>\n";
    print "<tr><td></td><td class=\"subsubt\">
        Variables are lower case letters from <span class=\"tt\">a</span> to 
        <span class=\"tt\">z</span> plus </td></tr>\n";
    # vardig
    print "<tr><td class=\"inp\">";
    _checkbox($session->getconf("vardig"),"vardig");
    print "</td>\n";
    print "<td> <span class=\"tt\">a1</span> &ndash; a letter followed by a single digit </td></tr>\n";
    # var_dig
    print "<tr><td class=\"inp\">";
    _checkbox($session->getconf("var_dig"),"var_dig");
    print "</td>\n";
    print "<td> <span class=\"tt\">a_1</span> &ndash; a letter followed by an underscore and a single digit </td></tr>\n";
    # vardig=2    
    print "<tr><td class=\"inp\">";
    _checkbox($session->getconf("vardig")>1,"vardig2");
    print "</td>\n";
    print "<td> <span class=\"tt\">a123</span> &ndash; a letter followed by any sequence of digits </td></tr>\n";
    # var_dig=2
    print "<tr><td class=\"inp\">";
    _checkbox($session->getconf("var_dig")>1,"var_dig2");
    print "</td>\n";
    print "<td> <span class=\"tt\">a_123</span> &ndash; a letter followed by an underscore and any sequence of digits </td></tr>\n";
    # separator character
    print "<tr><td> </td><td class=\"subsubt\">
         Variable sequences are separated by the character </td></tr>\n";
    my $sepchars= _sepchars(); 
    for (my $i=0;$i<scalar @$sepchars; $i+=2){
        print "<tr><td class=\"inp\"><input type=\"radio\" name=\"sepchar\" value=\"",$i+1,"\"";
        print " checked=\"checked\"" if($sepchars->[$i+1] eq $session->getconf("sepchar"));
        print " onchange=\"wi_showButtons();\"";
        print "></td><td> <span class=\"tt\">",$sepchars->[$i+1],
            "</span> &nbsp; (",$sepchars->[$i],")</td></tr>\n";
    }
    # LP response time
    print "<tr class=\"subt\"><td></td><th>LP response time</th></tr>\n";
    print "<tr><td class=\"inp\">";
    _select(_timeout(),$session->getconf("timeout"),"timeout");
    print "</td><td>Time limit for solving an LP instance </td></tr>\n";
    print <<TRAILER;
    </tbody></table></div> <!-- config -->
TRAILER
    wHtml::html_tail();
}
#################################################################
# parse the result
sub _checkamong { # value should be among those which are offered
    my($arr,$val)=@_;
    return "" if(!$val);
    for (my $i=0;$i<scalar @$arr; $i+=2){
        return $val if($arr->[$i] eq $val);
    }
    return "";
}
sub Parse {
    my($session)=@_;
    return if($session->getpar("reset")); # don't save
    my $config={};
    # modified
    $config->{modified} = $session->getconf("modified");
    #font
    my $new=_checkamong(_fontfamily(),$session->getpar("settingfont"));
    $config->{font} = $new || $session->getconf("font");
    #fontsize
    $new=_checkamong(_fontsize(),$session->getpar("fontsize"));
    $config->{fontsize} = $new || $session->getconf("fontsize");
    # tablesize
    $new=_checkamong(_tablesize(),$session->getpar("tablesize"));
    $config->{tablesize} = $new || $session->getconf("tablesize");
    # macro args
    $config->{macroarg} = $session->getpar("macroarg") ? 1 : 0;
    # syntax
    $config->{style}    = $session->getpar("simplesyntax") ? 1 : 0;
    $config->{parent}   = $session->getpar("parent") ? 1 : 0;
    $config->{braces}   = $session->getpar("braces") ? 1 : 0;
    $config->{varprime} = $session->getpar("varprime") ? 1 : 0;
    $config->{vardig}   = $session->getpar("vardig2") ? 2 :
                          $session->getpar("vardig") ? 1 : 0;
    $config->{var_dig}  = $session->getpar("var_dig2") ? 2 :
                          $session->getpar("var_dig") ? 1 : 0;
    # sepchar
    my $sepchars=_sepchars(); my $i=$session->getpar("sepchar");
    $config->{sepchar} = ($i =~ /^\d\d?$/ && ($i&1) && $sepchars->[$i]) ?
       $sepchars->[$i] : $session->getconf("sepchar");
    # LP timeout
    $new=_checkamong(_timeout(),$session->getpar("timeout"));
    $config->{timeout} = $new || $session->getconf("timeout");
    # check if it has changed at all
    my $same=1;
    foreach my $k(keys %$config){
        $same=0 if($config->{$k} ne $session->getconf($k)); 
    }
    return if($same);
    # save the config for future use
    $session->replace_configure($config);
    # and save it
    wUtils::write_user_config($session,$config);
}

1;


