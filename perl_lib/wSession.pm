###################
## wSession.pm
###################
##
## initialize session
##
###########################################################################
# This code is part of wITIP (a web based Information Theoretic Prover)
#
# Copyright (2017) Laszlo Csirmaz, Central European University, Budapest
# This program is free, open-source software. You may redistribute it
# and/or modify under the terms of the GNU General Public License (GPL).
# There is ABSOLUTELY NO WARRANTY, use at your own risk.
###########################################################################

package wSession;

use wAnApache;
use Apache2::Request;
use wDefault;
use wUtils;

use strict;

############################################################
=pod

=head1 wSession.pm

Initialize the session by getting all arguments (parameters) and default values.


=head2 Procedures

=over 2

=item $session = new wSession

Populats $session with arguments, default values, and with the session ID. 
Abort when $session is not defined.

=item $argument = $session->getpar("argname")

Retrieve the value of "argname" or the empty string if it was not defined.

=item $confvalue = $session->getconf("confname")

Retrieve the configuration value as defined globally in wDefault.pm, or as associated
with the session ID.

=item $session->setconf("confname",$value)

Replace the value of a configure tag.

=item $session->replace_configure($newconf)

Replaces the configure hash with the one given as the argument.

=item $error = $session->add_SSID($SSID)

Add (replace) the session ID with the given one. Returns 1 on error, and
zero otherwise.

=item $tempfile=$session->mktemp()

Creates a temporary file with the given session name space. Returns the
file name.

=item $secret=$session->get_secret()

Returns a secret 32 hexadecimal string. Creates the value when not found.


=back

=head2 Values

=over 2

=item $action = $session->{action}, $actionvalue = $session->{actionvalue}

Retrieves the action and the associated value when the web page has a parameter 
(presumably a button) defined as "action:<actionvalue>".

=item $SSID = $session->{SSID}

The session ID as supplied by the page. When wUtils::check_SSID($SSID) returns non-empty
error message, new session ID should be requested.

=back

=cut
###########################################################

sub new {
    my ( $class )=@_;
    my $self = {}; bless $self,$class;
    # parse request arguments
    my $request = Apache2::RequestUtil->request();
    # do not cache any of these pages 
    $request->no_cache(1);
    $self->{request_method}=$ENV{'REQUEST_METHOD'};
    $self->{pars}={};
    $self->{action}=""; $self->{actionvalue}="";
    my $ct = $ENV{'CONTENT_TYPE'};
    if($ct && $ct =~ /(multipart)|(applicat)/i ){
        my $req= Apache2::Request -> new;
        $self->{request} = $req;
        my @pm=$req->param;
        foreach my $key (@pm){
           my $pm=$req->param($key);
           $self->{pars}->{$key}=wUtils::utf8escape($pm);
           if($key =~ /^action_(.*)$/ ){
               $self->{action} = $1;
               $self->{actionvalue} = $self->{pars}->{$key};
           }
        }
    } else {
        foreach my $elem (split( /&/,($ENV{'QUERY_STRING'}||""))){
           my($t,$v)=split(/=/,$elem);
           next if(!defined($t));
           $t =~ tr /+/ /;
           $t =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C",hex($1))/eg;
           $v="" if(!defined $v );
           $v=~ tr /+/ /;
           $v=~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C",hex($1))/eg;
           $self->{pars}->{$t}=wUtils::utf8escape($v);
        }
    }
    wDefault::setting($self); # get some global values
    my $SSID=$self->{pars}->{SSID} // "";
    $SSID =~ s/^\s+//; $SSID =~ s/\s+$//;
    $self->{SSID} = $SSID;
    # %default is not a valid session ID
    $SSID="%default" if(wUtils::check_SSID($SSID));
    $self->{datadir} = wUtils::getDataDir($self->{setting}->{basedir},$SSID);
    $self->{stub} = $self->{datadir}."/".wUtils::purify($SSID);
    # figure out the local setting
    $self->{config}=wUtils::read_user_config($self);
    return $self;
}

# utility functions

sub add_SSID {
    my($self,$SSID)=@_;
    $SSID = "" if(!defined $SSID);
    $SSID =~ s/^\s+//; $SSID =~ s/\s+$//;
    $self->{SSID} = $SSID;
    # SSID is not a valid session ID
    return 1 if(wUtils::check_SSID($SSID));
    $self->{datadir} = wUtils::getDataDir($self->{setting}->{basedir},$SSID);
    $self->{stub} = $self->{datadir}."/".wUtils::purify($SSID);
    # figure out the local setting
    $self->{config}=wUtils::read_user_config($self);
    return 0;
}

sub getpar {
    my($self,$par)=@_;
    my $ret=$self->{pars}->{$par};
    return $ret // "";
}

sub getconf {
    my($self,$key)=@_;
    my $v=$self->{setting}->{$key};
    $v = $self->{config}->{$key} if(! defined $v); 
    return $v // "";
}

sub setconf {
    my($self,$tag,$value)=@_;
    $self->{config}->{$tag}=$value;
}

sub replace_configure {
    my($self,$conf)=@_;
    $self->{config}=$conf;
}

sub mktemp {
    my($self)=@_;
    my $pattern=$self->{stub}.$self->{setting}->{exttemp}.".XXXXXXX";
    my $mktemp=$self->getconf("mktemp");
    my $tmpfile=`$mktemp -q $pattern`;
    chomp $tmpfile;
    return $tmpfile;
}

sub get_secret {
    my($self)=@_;
    my $pam=$self->{stub}.$self->{setting}->{extpam};
    my $fh; my $secret;
    if(open($fh,"<",$pam)){
       $secret=<$fh>; close($fh);
       chomp $secret;
       return $secret;
    }
    # generate
    if(open($fh,"<","/dev/urandom")){
       my $raw;
       sysread($fh,$raw,16); close($fh);
       $secret=unpack("h32",$raw);
    } else {
       my $rnd=rand(16);
       $secret="";
       for(1..32){
           my $i=int($rnd);
           $rnd=($rnd-$i)*16;
           $secret .= chr(65+$i);
       }
    }
    if(open($fh,">",$pam)){
       print $fh  "$secret\n";
       close($fh);
    }
    return $secret;
}


1;

