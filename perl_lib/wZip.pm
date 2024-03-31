####################
## wZip.pm
####################
##
## handle macros
##
###########################################################################
# This code is part of wITIP (a web based Information Theoretic Prover)
#
# Copyright 2017-2024 Laszlo Csirmaz, UTIA, Prague
# This program is free, open-source software. You may redistribute it
# and/or modify under the terms of the GNU General Public License (GPL).
# There is ABSOLUTELY NO WARRANTY, use at your own risk.
###########################################################################

package wZip;

use wUtils;
use strict;

########################################################
=pod

=head1 wITIP perl modules

=head2 wZip.pm

Create save file; and parse the loaded file

=over 2

=item wITIP save file format

The itip save file is an ASCII file containing all relevant data.
The first lines is

SSID=I<SSID>

followed by data for config, macro, macro history, constraints,
constraints history, id table, checking history. Each part starts
with a line specifying the data and the number of lines, e.g.,

config=I<lineno>

This line is followed by I<lineno> many lines - the content of the 
corresponding data. I<linenl> can be zero when this part is
empty. The last line of the witip file is

MAC=I<authentication code>

which is computed by computing the MD5 digest of all lines in the file
together with the secret value returned by $session->get_secret()

=back

=head2 Procedures

=over 2

=item $filename=wZip::create($session)

Creates the file which will be zipped. Returns the file name,
or empty string in case of error (the file cannot be created).
The filename has the form I<SSID>.I<random>.txt to denote that
it is a text file.

=item $result=wZip::reload($session,$filename,$filetype)

Reloads the configuration from the uploaded file which should be either
zipfile ($filetype==0) or an ascii file ($filetype==1).  Returns the empty
string on success, otherwise the error message.  Resets the configuration,
and clears the {modified} field which indicates that something has changed.

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
# $errormessage=wZip::reload($session,$file,$filetype)
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
    my($session,$fname,$ftype)=@_; # $ftype==1: ascii
    my $io;
    if(!$fname){
        return "No filename was given";
    }
    if($ftype){
        if(!open($io,"<",$fname)){ return "Cannot open file \"$fname\""; }
    } elsif( !open($io,"-|",$session->getconf("unzip")." -qq -p $fname")){
        return "Cannot unzip file \"$fname\"";
    }
    use Digest::MD5;
    my $mac = Digest::MD5->new;
    $mac->add($session->get_secret());
    # SSID=<SSID>
    my $line=<$io>;
    $mac->add($line); chomp $line;
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

