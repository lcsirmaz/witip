####################
## wLogoutPage.pm
####################
##
## Change session / save / open 
##
###########################################################################
# This code is part of wITIP (a web based Information Theoretic Prover)
#
# Copyright (2017) Laszlo Csirmaz, Central European University, Budapest
# This program is free, open-source software. You may redistribute it
# and/or modify under the terms of the GNU General Public License (GPL).
# There is ABSOLUTELY NO WARRANTY, use at your own risk.
###########################################################################

package wLogoutPage;

use wHtml;
use wUtils;
use strict; 
##############################################################
=pod

=head1 wITIP perl modules

=head2 wLogoutPage.pm

Render and process print / save / open page

=over 2

=item wLogoutPage::Page($session)

Render the page under the "session" tab: print, save, change session,
and open. Print opens a new window with all printable material. Save
is a link to a dynamic address where the actual content is wrapped into
a zip file and returned. Change session goes to the opening page, and
open retrieves a saved content and restores the session.

=item wLogoutPage::Parse($session)

Handles the requests from the page. Redirects to the login page when
clicked on "change session"; and checks the uploaded file when clicked
on "open", reloads the content and redirects to the main page.

=back

=cut
##############################################################
# generate some random 4-character string
sub fourchar {
    my $i=shift;
    $i ^= ($i>>24); $i &=0xffffff; $i *=25; 
    my $txt="";
    for(1..4){
        $txt .= ('A'..'Z','0'..'9')[$i%36];
        $i=int($i/36);
    }
    return $txt;
}

sub Page {
    my($session)=@_;
    wHtml::plain_header($session,"wITIP session", {
        banner => "session",
        lcss   => "session",
        javascript => "
var wi_saved=0;
function wi_saveButton(){
    if(wi_saved) return false;
    wi_saved=1;
    setTimeout(function(){
        document.getElementById('form-main').submit();
    },1000);
    return true;
}
function wi_commandButton(){
    var fname=document.getElementById('commandfile').value;
    if(! fname){
        alert('No command file is specified'); return false;
    }
    if(! fname.match(/[.]txt\$/i)){
        alert(fname +' is not a wITIP command file'); return false;
    }
    return confirm('All macros and constraints will be deleted. Continue?');
}
function wi_importButton(){
    var fname=document.getElementById('importfile').value;
    if(! fname){
        alert('No file was specified '); return false;
    }
    if(! fname.match(/[.]zip\$/i)){
        alert(fname +' is not a wITIP export file'); return false;
    }
    return confirm('All changes to this session will be lost. Continue?');
}
",
    });
    ## values used later
    my $SSID = $session->{SSID}; my $rnd=fourchar(time);
    # saveurl
    my (undef,undef,undef,$day,$mon)= localtime(time);
    my $saveurl= $SSID . sprintf("_%s%02d_",
       qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)[$mon],
       $day). $rnd;
    # replace # and / by their %2F codes
    $saveurl =~ s/([#\/])/sprintf("%%%02X",ord($1))/ge;
    $saveurl = $session->getconf("basecgi")."/get/".
       wUtils::htmlescape(wUtils::urlescape("$saveurl"));
    # listurl
    my $listurl = $saveurl . ".txt";
    $saveurl .= ".zip";
    # printurl
    my $printurl = $session->getconf("basecgi")."/print.html?".
       "SSID=".wUtils::htmlescape(wUtils::urlescape($SSID)."&chk=".
       $rnd);
    ##
    # spacer
    print "<div style=\"height: 5px;\"> <!-- spacer --> </div>\n";
    # error
## HTML code
## <p class="errmsg"> .... </p>
    if($session->{errmsg}){
        print "<div class=\"errmsg\">",$session->{errmsg},"</div>\n";
    }
## HTML code
## <div><table><tbody>
##   <tr><td> BUTTON </td> </td> explanation </td></tr>
## </tbody></table></div>    
    print "<div class=\"sesscontainer\"><table class=\"sesstable\">",
          "<tbody>\n";
    # session ID, indicate whether modified
    my $modified="";
    my $essid=wUtils::htmlescape($SSID);
    $modified=" <span class=\"smodified\">(modified)</span> "
        if($session->getconf("modified"));
    # change session ID
    print "<tr class=\"subt\"><td class=\"firstcol\"> </td>\n",
      "<th class=\"stitle secondcol\"> Change session </th></tr>\n";
    print "<tr><td class=\"sbutton\"> ",
      "<input class=\"subutton\" type=\"submit\" name=\"changesession\"",
      " value=\"change\" title=\"change your session\"> </td>\n",
      "<td class=\"expl\"> switch session &quot;$essid&quot; to a different one;",
      " return later to continue your work</td></tr>\n";
    # Print, list, execute
    print "<tr class=\"subt\"><td> </td>\n",
      "<th class=\"stitle\"> Print content, save and execute commands </th></tr>\n";
    # print
    print "<tr><td class=\"sbutton\"> ",
       "<a class=\"abutton\" href=\"$printurl\" target=\"_blank\"",
       " title=\"print expressions, macros, constraints\"> print </a></td>\n",
       "<td class=\"expl\"> create a printout of the current session in a new window",
       " </td></tr>\n";
    # download commands
    print "<tr><td class=\"sbutton\"> ",
       "<a class=\"abutton\" href=\"$listurl\"",
       " onclick=\"return wi_saveButton();\"",
       " title=\"create commands which add macros, constraints and the last query \"> save </a></td>\n",
       "<td class=\"expl\"> download an editable list of commands creating current macros, constraints and the last query",
       " </td></tr>\n";
    # execute
    print "<tr><td class=\"sbutton\"> ",
      "<input class=\"subutton\" type=\"submit\" name=\"execute\"";
    if($session->getconf("modified")){ # confirm button  
        print " onclick=\"return wi_commandButton(); \"",
    }
    print " value=\" execute \" title=\"add macros, constraints, and ask a query\"> </td>\n",
      "<td class=\"expl\"><div class=\"line1\">",
      " execute command list from the external file ",
      "<input class=\"browse\" id=\"commandfile\" type=\"file\" size=\"35\" name=\"commands\"> </div>\n";
    print "</td></tr>\n";
    # backup and restore
    print "<tr class=\"subt\"><td> </td>\n",
      "<th class=\"stitle\"> Backup and restore </th></tr>\n";
    # export
    print "<tr><td class=\"sbutton\"> ",
       "<a class=\"abutton\" href=\"$saveurl\"",
       " onclick=\"return wi_saveButton();\"",
       " title=\"export the current session\"> export </a></td>\n",
       "<td class=\"expl\"> export the current content of session &quot;$essid&quot; to a local file ",
       "</td></tr>\n";
    # import
    print "<tr><td class=\"sbutton\"> ",
      "<input class=\"subutton\" type=\"submit\" name=\"open\"";
    if($session->getconf("modified")){ # confirm button  
        print " onclick=\"return wi_importButton();\"",
    }
    print " value=\" import \" title=\"import an exported session\"> </td>\n",
      "<td class=\"expl\"><div class=\"line1\">",
      " restore session &quot;$essid&quot; content from an exported copy ",
      "<input class=\"browse\" id=\"importfile\" type=\"file\" size=\"35\" name=\"witip\"> </div>\n";
    print "</td></tr>\n";

    print "</tbody></table></div><!-- sesscontainer -->\n";

    wHtml::html_tail();
}

####################################################################

sub Parse {
    my($session)=@_;
    return if($session->getpar("comingfrom") ne "session");
    # change session
    if($session->getpar("changesession")){
       # go to the login page
       $session->{loginmessage}="Please specify the session ID you want to use";
       $session->{actionvalue}="login";
       return;
    }
    if($session->getpar("execute")){
      use Apache2::Upload;
      my $upload=$session->{request}->upload("commands");
      if(!$upload){
         $session->{errmsg}="No command file was selected.";
         return;
      }
      use wList;
      $session->{errmsg}=wList::Execute($session,$upload->tempname(),$session->getpar("commands"));
      return;
    }
    if($session->getpar("open")){
      # check the witip field
      use Apache2::Upload;
      my $upload=$session->{request}->upload("witip");
      if(!$upload){
        $session->{errmsg}="No exported witip file was selected."; 
        return;
      }
      my $fh=$upload->tempname();
      my $filetype=$session->getconf("filetype");
      $filetype=`$filetype -b $fh`;
      if($filetype =~ /^ascii/i ){
          $filetype=1;
      } elsif($filetype =~ /^zip/i ){
          $filetype=0;
      } else {
         $session->{errmsg}="The file you specified ($upload) is not a witip exported file.";
         return;
      }
      use wZip;
      my $result=wZip::reload($session,$fh,$filetype);
      if( $result =~ m/^SSID mis/ ){ # SSID mismatch
         $session->{errmsg}=
           "The witip file you specified ($upload) belongs to a different
              session. Only files with the same session ID can be returned.";
         return;
      }
      if($result){# other error
         print STDERR "$result\n"; # save message in Apache log as well
         $session->{errmsg}=
           "The file you specified ($upload) is either not a witip file,
            or it is corrupted";
         return;
      }
      # content has been restored; go to the check page
      $session->{actionvalue}="check";
      return;
    }
}


1;

