##################
## wLoginPage.pm
##################
##
## render the very first page
##
###########################################################################
# This code is part of wITIP (a web based Information Theoretic Prover)
#
# Copyright (2017) Laszlo Csirmaz, Central European University, Budapest
# This program is free, open-source software. You may redistribute it
# and/or modify under the terms of the GNU General Public License (GPL).
# There is ABSOLUTELY NO WARRANTY, use at your own risk.
###########################################################################

package wLoginPage;

use strict;

############################################################
=pod

=head1 wITIP perl modules

=head2 wLoginPage.pm

Render the wITIP opening page with error message

=over 2

=item wLoginPage::Page($session,$err)

Render the opening page requesting the session ID. If $err is not empty, 
format it as an error message.

=back

=cut
############################################################

use wHtml;
sub Page {
    my($session,$errmsg)=@_;
    wHtml::plain_header($session,"wITIP login",{
       lcss=>"login",
       bodyattr=>"onload=\"document.witip.SSID.focus();\"",
    });
    print <<CONTENT;
<div class="subtitle">wITIP</div>
<p class="smallsize">
This is <b>wITIP</b>, a web based Information Theoretic Inequality Prover.
</p>
CONTENT
    if($errmsg){
        print <<ERRMSG;
<p class="errmsg">
$errmsg
</p>
ERRMSG
    } else {
        print <<SPECIFY;
<p class="smallsize">
Please specify your session ID to start working. The ID should start with a letter
or hash tag; your name or your e-mail address is a good choice.
</p>
SPECIFY
    }
    my $action = $session->getconf("basecgi")."/main.html";
    my $SSID=$session->{SSID};
    print <<LOGIN;
<div class="logincontainer">
<p>Your session ID</p>
<p><input type="text" name="SSID" style="width: 90%" value="$SSID"></p>
<div><!-- dummy --></div>
<p><input class="logsubmit" type="submit" name="action_start" value="CONTINUE">
</div>
LOGIN
    wHtml::html_tail();
}

1;

