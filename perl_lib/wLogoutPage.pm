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
       wUtils::htmlescape(wUtils::urlescape("$saveurl")).".zip";
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
        print "<p class=\"errmsg\">",$session->{errmsg},"</p>\n";
    }
## HTML code
## <div><table><tbody>
##   <tr><td> BUTTON </td> </td> explanation </td></tr>
## </tbody></table></div>    
    print "<div class=\"sesscontainer\"><table class=\"sesstable\">",
          "<tbody>\n";
    # session ID, indicate whether modified
    my $modified="";
    $modified=" <span class=\"smodified\">(modified)</span> "
        if($session->getconf("modified"));
    print "<tr class=\"subt\"><td class=\"firstcol\"> </td>\n",
      "<th class=\"stitle secondcol\"> Session ID: ",
      wUtils::htmlescape($SSID),
      "$modified </td></tr>\n";
    # print
    print "<tr><td class=\"sbutton\"> ",
       "<a class=\"abutton\" href=\"$printurl\" target=\"_blank\"",
       " title=\"print expressions, macros, constraints\"> print </a></td>\n",
       "<td class=\"expl\"> get a printable form of the current session",
       " </td></tr>\n";
    # save
    print "<tr><td class=\"sbutton\"> ",
       "<a class=\"abutton\" href=\"$saveurl\"",
       " title=\"save current session\"> save </a></td>\n",
       "<td class=\"expl\"> save the current state of the session",
       " on your computer </td></tr>\n";
    # new session
    print "<tr class=\"subt\"><td> </td>\n",
      "<th class=\"stitle\"> New session </td></tr>\n";
    # change session ID
    print "<tr><td class=\"sbutton\"> ",
      "<input class=\"subutton\" type=\"submit\" name=\"changesession\"",
      " value=\"change\" title=\"change your session\"> </td>\n",
      "<td class=\"expl\"> change this session to a different one;",
      " return later to continue </td></tr>\n";
    # open from saved
    print "<tr><td class=\"sbutton\"> ",
      "<input class=\"subutton\" type=\"submit\" name=\"upload\"",
      " value=\" open \" title=\"open saved session\"> </td>\n",
      "<td class=\"expl\"><div class=\"line1\">",
      " restore session content as was saved in ",
      "<input class=\"browse\" type=\"file\" size=\"35\" name=\"witip\" value=\"\"> </div>\n";
    if($session->getconf("modified")){ # warning
      print "<div class=\"line2\"> Warning: if you choose this option,",
      " all changes to this session will be lost.</div>\n";
    }
    print "</td></tr>\n";

    print "</tbody></table></div><!-- sesscontainer --></div>\n";

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
    # check the witip field
    use Apache2::Upload;
    my $upload=$session->{request}->upload("witip");
    if(!$upload){
        $session->{errmsg}="No saved witip file was selected."; 
        return;
    }
    my $fh=$upload->tempname();
    my $filetype=`/usr/bin/file -b $fh`;
    if($filetype !~ /^zip/i ){
       $session->{errmsg}="The file you specified ($upload) is not a witip file.";
       return;
    }
    use wZip;
    my $result=wZip::reload($session,$fh);
    if( $result =~ m/^SSID mis/ ){ # SSID mismatch
       $session->{errmsg}=
         "The witip file you specified ($upload) belongs to a different
            session. Only files with the same session ID can be opened.";
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


1;

