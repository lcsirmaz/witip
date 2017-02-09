##################
## wHtml.pm
##################
##
## Html head and tail
##
###########################################################################
# This code is part of wITIP (a web based Information Theoretic Prover)
#
# Copyright (2017) Laszlo Csirmaz, Central European University, Budapest
# This program is free, open-source software. You may redistribute it
# and/or modify under the terms of the GNU General Public License (GPL).
# There is ABSOLUTELY NO WARRANTY, use at your own risk.
###########################################################################

package wHtml;

use strict;
use wUtils;

######################################################
=pod

=head1 wITIP perl modules

=head2 wHtml.pm

Create the head and tail code of the HTML pages

=over 2

=item wHtml::plain_header($session,$title,$options)

Creates the HTML head for the page using $title as the
page title. These fields in the $options are recognized:

    lcss       => css files to be put into the header as links
    ljs        => javascript source files (header)
    javascript => inline javascript text which goes between <script> and </script>
    style      => inline css style
    bodyattr   => attribute to the <body> tag; typically an onload script
    action     => the target in the (only) form of the page, or main.html
    banner     => if present, creates the banner on the top of the page

When using a banner, the hidden variables 'SSID', 'comingfrom', 'action_goingto'
are filled.  'comingfrom' is this page (the value of the banner option);
'action_goingto' is the page to go to; when it is the same as 'comingfrom' then
some other submit button was fired and not one of these navigation ones.

The javascript variable witipAllDisabled should be set to non-zero when the banner
cannot be used to leave the page. This happens on macro and constraints pages when
the 'delete' option is chosen.


=item wHtml::html_tail()

Closes the form on the HTML page and appends the copyright notice.

=back

=cut
######################################################

sub _linkcss {
    my($base,$lcss)=@_;
    return if(!defined $lcss);
    if(ref($lcss) ne "ARRAY"){ $lcss=[ $lcss ]; }
    foreach my $l(@$lcss){
        print "  <link type=\"text/css\" rel=\"stylesheet\" ",
         "href=\"$base/css/$l.css\">\n";
    }
}
sub _jssrc {
    my($base,$js)=@_;
    return if(!defined $js);
    if( ref($js) ne "ARRAY") { $js = [ $js ]; }
    foreach my $j(@$js){
        print "  <script type=\"text/javascript\" ",
          "src=\"$base/js/$j.js\"></script>\n";
    }
}
sub _jsinline {
    my($js)=@_;
    return if(!$js);
    $js =~ s/^\s+//; $js =~ s/[\s\n]+$//;
    print "  <script type=\"text/javascript\">\n",
          "$js\n  </script>\n";
}
sub _csinline {
    my($style)=@_;
    return if(!$style);
    $style =~ s/^\s+//; $style =~ s/[\s\n]+$//;
    print "   <style type=\"text/css\">\n",
       "$style\n   </style>\n";
}

sub plain_header {
    my ($session,$title,$options) = @_;
    $options={} if(!defined $options);
    my $basehtml=$session->getconf("basehtml");
    print <<HEADTOP;
<!DOCTYPE HTML>
<html lang="en">
<head>
  <title>$title</title>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
HEADTOP
    _linkcss($basehtml,$options->{lcss}); ## css
    _jssrc($basehtml,$options->{ljs});    ## js source
    _jsinline($options->{javascript});    ## js inline
    _csinline($options->{style});         ## css inline
    if($options->{banner}){
        _linkcss($basehtml,"global");
        my $baseURL=$session->getconf("basecgi");
        _jsinline("
var witipAllDisabled=0;
var witipBaseURL='$baseURL';
function wi_gotoPage(page){
    if(witipAllDisabled) return;
    document.getElementById('goingto').value=page;
    document.getElementById('form-main').submit();
}
"       );
    }
    print "</head>\n";
    print "<body",($options->{bodyattr} ? " ".$options->{bodyattr} : ""),
          ">\n",
          "<div class=\"main\">\n";
    my $action=$session->getconf("basecgi")."/".($options->{action} || "main.html" );
    print "<form name=\"witip\" id=\"form-main\" method=\"post\" action=\"$action\" enctype=\"multipart/form-data\" accept-charset=\"utf-8\">\n";
    my $banner=$options->{banner};
    if($banner){
        print "<div class=\"banner\">\n";
        print "<input type=\"hidden\" id=\"SSID\" name=\"SSID\" value=\"",$session->{SSID},"\">\n";
        print "<input type=\"hidden\" name=\"comingfrom\" value=\"$banner\">\n";
        print "<input type=\"hidden\" name=\"action_goingto\" value=\"$banner\" id=\"goingto\">\n";
        # SSID floats right
        my $SSID=$session->{SSID};
        my $modified=$session->getconf("modified");
        print "<div class=\"ssid\">",
           " <span class=\"legend\"> session ID:",
           " <span class=\"ssvalue\"> $SSID",
           "<span class=\"jobtitle\" id=\"wi_modified\">$modified</span> </span>";
        print "</span></div>\n";
        # 
        print "<table><tbody><tr>";
        print "<td class=\"brand\">wITIP</td>\n";
        my $before='b';
        foreach my $title (qw( wITIP config macros constraints check session )){
           my $help={
              config => "configure wITIP",
              macros => "define / view macros",
              constraints => "define /view constraints",
              check => "check entropy expressions",
              wITIP => "how to use wITIP",
              session => "change session / sign out",
           } -> {$title};
           if($title eq $options->{banner}){
               print "<td class=\"actual\" title=\"$help\">$title</td>\n";
               $before='a'; # now it is after
           } else {
               print "<td class=\"link$before\" title=\"$help\" ",
                 "onclick=\"wi_gotoPage('$title');\"> $title </td>\n";
           }
        }
        print "<td class=\"spacer\"> </td>\n";
        print "</tr></tbody></table>\n";
        print "</div><!-- banner -->\n";
    }
}

sub html_tail {
    print <<TAIL;
</form></div><!-- main -->
<p class="ad">wITIP &copy; 2017, created by <a
href="http://www.renyi.hu/~csirmaz" target="_blank">Laszlo Csirmaz</a> at CEU</p>
</body>
</html>

TAIL
}


1;

