####################
## wZip.pm
####################
##
## handle macros
##
###########################################################################
# This code is part of wITIP (a web based Information Theoretic Prover)
#
# Copyright (2017) Laszlo Csirmaz, Central European University, Budapest
# This program is free, open-source software. You may redistribute it
# and/or modify under the terms of the GNU General Public License (GPL).
# There is ABSOLUTELY NO WARRANTY, use at your own risk.
###########################################################################

package wZip;

use wUtils;
use strict;

########################################################
=pod

=head1 wZip.pm

Create save files, and parse the loaded files

=over 2

=item File format

The itip file is an ASCII file containing all relevant data.
The first lines is

    SSID=<SSID>

followed by data for config, macro, macro history, constraints,
constraints history, id table, checking history. Each part starts
with a line specifying the data and the number of lines, e.g.,

    config=<lineno>

This line is followed by <lineno> many lines - the content of the 
corresponding data. The last of the witip line is

    MAC=<authentication code>

which is computed by computing the digest of all lines saved in the file
together with the secret value returned by $session->get_secret()

=back

=head2 Procedures

=over 2

=item $filename=wZip::create($session)

Creates the file which will be zipped. Returns the file name,
or empty string in case of error (the file cannot be created).

=item $result=wZip::reload($session,$filename)

Reloads the configuration from the uploaded zipfile. Returns the
empty string when successful, otherwise an error message.
Resets the configuration, and clears the {modified} field which
indicates that something has changed.

=back

=cut
########################################################

# which extensions are saved in which order
my @saveitems=qw(
    config macro hismacro constr hiscons table hisexpr );

########################################################
# wZip::create($session)
# create the file containing all content

sub create {
    my($session)=@_;
    my $tmpfile=$session->mktemp("txt");
    my $fh;
    if(!open($fh,">",$tmpfile)){
       print STDERR "Cannot create temporary file $tmpfile\n";
       return "";
    }
    use Digest::MD5;
    my $mac = Digest::MD5->new;
    $mac->add($session->get_secret());
    my $line="SSID=".$session->{SSID}."\n";
    $mac->add($line); print $fh $line;
    foreach my $tag (@saveitems){
       my $fh2; my @cont=();
       if(open($fh2,"<",$session->{stub}.$session->getconf("ext$tag"))){
          while(<$fh2>){ push @cont, $_; }
          close($fh2);
       }
       $line="$tag=". scalar @cont ."\n";
       $mac->add($line); print $fh $line;
       foreach my $l (@cont){
           $mac->add($l); print $fh $l;
       }
    }
    print $fh "MAC=",$mac->hexdigest,"\n";
    close($fh);
    return $tmpfile;
}

###############################################################
# $errormessage=wZip::reload($session,$file)
# reload content from the given zipped file

#error, unlink temporary files
sub rerror {
    my($msg,$files)=@_;
    foreach my $f (@$files){
        unlink $f if($f ne "");
    }
    return $msg;
}

sub reload {
    my($session,$fname)=@_;
    my $io;
    if(!$fname || !open($io,"-|",$session->getconf("unzip")." -qq -p $fname")){
        return "Cannot unzip filename \"$fname\"";
    }
    use Digest::MD5;
    my $mac = Digest::MD5->new;
    $mac->add($session->get_secret());
    # SSID=<SSID>
    my $line=<$io>; $mac->add($line); chomp $line;
    return "wrong first line ($line)"
       if($line !~ /^SSID=(.*)$/ ); # error
    return "SSID mismatch ($line)"
       if($1 ne $session->{SSID});
    my @tmpfiles=();
    foreach my $tag (@saveitems){
       $line=<$io>; $mac->add($line); chomp $line;
       return rerror("wrong $tag line ($line)",\@tmpfiles)
          if($line !~ /^$tag=(\d+)$/ );
       my $cnt=$1;
       return rerror("counter out of range ($line)",\@tmpfiles)
          if($cnt>50000);
       if($cnt==0){ # no file
          push @tmpfiles, "";
          next;
       }
       my $fh2; my $file=$session->{stub}.$session->getconf("ext$tag");
       my $tmpfile=$session->mktemp();
       push @tmpfiles,$tmpfile;
       if(!open($fh2,">",$tmpfile)){
           return rerror("Cannot create tmpfile $tmpfile",\@tmpfiles);
       }
       while($cnt>0){
          $line=<$io>; $mac->add($line); print $fh2 $line;
          $cnt--;
       }
       close($fh2);
    }
    $line=<$io>; chomp $line;
    close($io);
    return rerror("MAC line expected ($line)",\@tmpfiles)
      if($line !~ /^MAC=([a-f0-9]*)$/);
    
    my ($old,$new)=($1,$mac->hexdigest);
    return rerror("MAC mismatch (old=$old, new=$new)",\@tmpfiles)
      if($old ne $new);
    # all is done, rename files
    my $idx=0;
    foreach my $tag (@saveitems){
        my $file=$session->{stub}.$session->getconf("ext$tag");
        unlink($file); 
        if($tmpfiles[$idx] ne "" && !rename($tmpfiles[$idx],$file)){
           print STDERR "Load: cannot rename temp file to $file\n";
        }
        $idx++;
    }
    # reload config
    $session->{config} = wUtils::read_user_config($session);
    if($session->getconf("modified")){ # clear changed flag
        $session->setconf("modified","");
        wUtils::write_user_config($session);
    }
    return "";
}


1;

