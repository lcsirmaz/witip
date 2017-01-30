##################
## wUtils.pm
##################
##
## wITIP utility functions
##
###########################################################################
# This code is part of wITIP (a web based Information Theoretic Prover)
#
# Copyright (2017) Laszlo Csirmaz, Central European University, Budapest
# This program is free, open-source software. You may redistribute it
# and/or modify under the terms of the GNU General Public License (GPL).
# There is ABSOLUTELY NO WARRANTY, use at your own risk.
###########################################################################

package wUtils;

# use base 'Exporter';
# our @EXPORT = qw( simplehash  getDataDir EPS htmlescape);

use strict;
use wDefault;

############################################################
=pod

=head1 wUtils.pm

Utility functions

=head2 Auxiliary procedures and constants

=over 2

=item Constant EPS

The eps value, smaller values are rounded to zero. The default
value is 1e-9.

=item $hash = wUtils::simplehash($string)

Computes 12 hexdigit hash of the given string. A fast, but
not secure hash function.

=item $dir = wUtils::getDataDir($base,$sessid);

Returns the directory which stores the files associated with
the session id $sessid. Creates all directories along the
path when necessary. 

=item $escaped = wUtils::utf8escape($string)

Escapes all utf8 non-ascii characters in the string by their
xml encoding as `&#1234;'

=item $escaped = wUtils::htmlescape($string)

Replaces all non html safe ascii characters by their xml
encoding, except for & which is replaced by `&amp;'.

=item $url = wUtils::urlescape($string)

Encodes special characters such as white space, ?, #, =, %, etc.
so that they can appear in an URL.

=item $errmsg = wUtils::check_SSID($SSID)

Returns an error message when $SSID contains strange characters, too short,
does not start with a letter, or is the magic word "default".

=item $purified = wUtils::purify($string)

The argument is a conforming session ID (thus no strange characters such as
backslash, quote, national characters). Replaces spaces by underscore, and
slashes by % to form a valid filename.

=item $label = wUtils::get_label($session)

Returns the next unique label (integer) using locking.

=back

=head2 Input / output procedures

Data is associated to SSID which, in turn, identifies the user.
Data is stored in files with the same basename but different extensions. 
Both the working directory and the base filename is derived from SSID.

=over 2

=item $config = wUtils::read_user_config($session)

Returns the user-defined config values, or the default ones if
none has been stored yet. 

=item wUtils::write_user_config($session,$config)

Stores the content of the $config hash in a permanent file so that
subsequent read_user_config() returns it. Selectors in $config must
be alphanumeric. Error messages go to STDERR (apache log). If
$config is missing, saves the system configuration.

=item $macros = wUtils::read_user_macros($session)

Reads user defined macros, or returns the default ones. The array
of macros is cached in $session; the returned value is a pointer
to the cached array. Make a local copy before modifying.

=item wUtils::write_user_macros($session,$macros,$replace)

Saves the content of the $macros array as the set of new macros.  Replace
the cached version of macros if $replace is true.  Error messages go to
STDERR (apache log).

=item $id_table = wUtils::read_user_id_table($session)

Returns the table containing random variables names, or an empty
table if no names have been saved. The table is used to match 
variables in constraints and variables used in the formula to be
checked. The table is cached in $session, make a local copy before
modifying it.

=item wUtils::write_user_id_table($session,$table)

Saves the content of the variable name table $table. Does not replace
the cached version. Error messages go STDERR (apacke log).

=item $constraints = wUtils::read_user_constraints($session)

Returns all constraints including disabled ones. The constraints use
the actual id_table returned by read_user_id_table(). The array is
cached in $session.

=item wUtils::write_user_constraints($session,$constraints,$replace)

Saves the specified set of constraints. Replace the cached instance
when $replace is true. Error messages go to STDERR (apache log).


=item wUtils::read_user_history($session,$type)

Read the user history. Returns a hash with the fields

    hist  array reference to history lines
    limit maximal number of lines in the array
    n     total number of lines filled, it is between zero (no line) and limit
    end   first not filled line in circular order

Skips lines which are the same as the previous one.

=item wUtils::write_user_history($session,$type,$history)

Appends $history to the history file of type $type. The argument $history can
be a string or an array of strings.

=item wUtils::replace_expr_history($session,$history)

Replaces present expr history with the lines described in the second argument.

=item wUtils::set_modified($session)

Sets the "modified" flag and saves the configuration

=back

=cut
############################################################

use constant EPS => 1e-9;
use wDefault;

#######################
sub simplehash { # a simple has function giving 12 hex digits
    my $str=shift;
    $str="12345678" . $str . $str; ## make it a string
    my $v1=0x13579b; my $v2=0xeca864;
    foreach my $s(split('',$str)){
       my $v=ord($s);
       $v1=(29*$v1+17*$v2+1259*$v)% 0x1010309;
       $v2=(23*$v2 + 257*$v1+1237*$v) % 0x1010507;
    }
    return sprintf("%06x%06x", (($v1>>9)^($v2<<7))&0xffffff,
          (($v2>>9)^($v1<<7))&0xffffff);
}

sub getDataDir {
    my($base,$label)=@_;
    my $hash=simplehash($label);
    my $dir= $base."/".substr($hash,0,2);
    unless( -d $dir){ mkdir $dir; }
    $dir .= "/$hash";
    unless( -d $dir){ mkdir $dir; }
    return $dir;
}

#### encoding #####

sub _XmlUtf8 { ## local sub to encode utf8 chars
    my($str)=@_;
    my $len=length($str);
    my $n=63; my @u;
    if($len==2){
        @u=unpack "C2",$str;
        $n=(($u[0]&0x3f)<<6)+($u[1]&0x3f);
    } elsif($len==3){
        @u=unpack "C3",$str;
        $n=(($u[0]&0x1f)<<12)+(($u[1]&0x3f)<<6)+($u[2]&0x3f);
    } elsif($len==4){
        @u=unpack "C4",$str;
        $n=(($u[0]&0x0f)<<18)+(($u[1]&0x3f)<<12)+(($u[2]&0x3f)<<6)+($u[3]&0x3f)
    }
    sprintf("&#%d;",$n);
}

sub utf8escape {
    my $arg=shift;
    $arg =~ s/([\xc0-\xdf].|[\xe0-\xef]..|[\xf0-\xff]...)/_XmlUtf8($1)/ges;
    $arg;
}

sub _encode {
    sprintf ("&#x%02x;",ord($_[0]) );
}

sub htmlescape {
    my $arg=shift;
    return "" if(! defined $arg);
    $arg =~ s/([\\\+\<\>\"\'%!\x00-\x1f\x7f-\xff])/_encode($1)/ge ;
    $arg =~ s/(\&\#[0-9a-fx]+;)|(\&)/(defined($1)?"$1":"\&amp;")/eg;
    $arg;
}

sub urlescape {
    my $arg=shift;
    return "" if(! defined $arg);
    $arg =~ s/([^a-zA-Z0-9\.,\$\*])/sprintf("%%%02X",ord($1))/ge;
    $arg;
}

## allowed characters in SSID are @#$*-+=/.:~ and should start with # or letter
sub check_SSID {
    my $SSID=shift;
    return "you did not specify the session ID"
        if(!defined($SSID) || $SSID eq "" );
    return "the session ID should start with a letter or a hashtag \#"
        if($SSID !~ /^[\#a-zA-Z]/);
    return "the session ID contains an unsupported special character. Use only +, -, /, \@, and dot"
        if($SSID =~ /[^a-zA-Z0-9_\@\#\-\+=\/.:~\s]/);
    return "the session ID is too short, it should contain at least 4 characters"
        if(length($SSID)<4);
    return "the session ID is too long"
        if(length($SSID)>30);
    return ""; # OK
}
# $SSID passed check_SSID; replace / by % and spaces by underscore
sub purify {
    my $res=shift; 
    $res =~ s/\//%/g; $res =~ s/\s/_/g;
    return $res;
}
#############################################################
# get unique label
sub get_label {
    my($session)=@_;
    my $lock=$session->{stub}.$session->getconf("extlock");
    my $lfile=$session->{stub}.$session->getconf("extlabel");
    my $label=0;
    use Fcntl ':flock';
    open(LOCKF,">>",$lock)||print STDERR "Cannot open lock file $lock\n";
    flock(LOCKF,LOCK_EX);
      if(open(FILE,$lfile)){
          $label = <FILE>; chomp $label;
          close(FILE);
      }
      $label++;
      if(open(FILE,">",$lfile)){
         print FILE "$label\n";
         close(FILE);
      }
    flock(LOCKF,LOCK_UN);
    close(LOCKF);
    return $label;
}
#############################################################
# read/write use config
sub read_user_config {
    my($session)=@_;
    my $fh;
    if(! open($fh,$session->{stub}.$session->getconf("extconfig"))){
        return wDefault::config();
    }
    my %data=();
    while(<$fh>){
        chomp;
        $data{$1}=$2 if(/^(\w+)=>(.*)$/);
    }
    close($fh);
    return \%data;
}
sub write_user_config {
    my($session,$data)=@_;
    my $file=$session->{stub}.$session->getconf("extconfig");
    my $tmpfile = $session->mktemp();
    my $fh;
    if(!open($fh,">",$tmpfile)){
        print STDERR "Cannot create temporary file $tmpfile for $file\n";
        return;
    }
    $data=$session->{config} if(! defined($data) );
    foreach my $k (keys %$data){
        next if($k !~ /^\w+$/ );
        print $fh "$k=>",$data->{$k},"\n";
    }
    close($fh);
    if(!rename($tmpfile,$file)){
        print STDERR "Cannot rename temp file to $file\n";
    }
}
## read/write macros
sub _print_expression {
    my($fh,$expr)=@_;
    my $chr="";
    foreach my $k (keys %$expr){
        print $fh "$chr$k,",$expr->{$k};
        $chr=",";
    }
}
sub read_user_macros {
    my($session)=@_;
    if(defined $session->{usermacros}){
        return $session->{usermacros};
    }
    my $fh;
    if(! open($fh,$session->{stub}.$session->getconf("extmacro"))){
        $session->{usermacros} = wDefault::macros();
        return $session->{usermacros};
    }
    my @macros=();
    while(<$fh>){
        chomp;
        s/\"(.*)$//;
        my $raw=$1; $raw="" if(!defined $raw);
        my @v=split(/,/);
        next if(scalar @v<7);
        my $text={};
        for (my $i=5;$i<scalar @v; $i+=2){
           $text->{$v[$i]}=$v[$i+1];
        }
        push @macros, {
            name => $v[0],
            argno => $v[1],
            septype => $v[2],
            std => $v[3],
            label => $v[4],
            raw => $raw,
            text => $text };
        }
    close($fh);
    $session->{usermacros} = \@macros;
    return $session->{usermacros};
}
sub write_user_macros {
    my($session,$macros,$replace)=@_;
    if($replace){ $session->{usermacros}=$macros; }
    my $file=$session->{stub}.$session->getconf("extmacro");
    my $tmpfile = $session->mktemp();
    my $fh;
    if(!open($fh,">",$tmpfile)){
       print STDERR "Cannot create temporary file $tmpfile\n";
       return;
    }
    foreach my $m (@$macros){
        print $fh "$m->{name},$m->{argno},$m->{septype},$m->{std},$m->{label},";
        _print_expression($fh,$m->{text});
        print $fh "\"$m->{raw}\n";
    }
    close($fh);
    if(!rename($tmpfile,$file)){
        print STDERR "Cannot rename temp file to $file\n";
    }
}
# read/write user id table
sub read_user_id_table {
    my($session)=@_;
    if(defined $session->{user_id_table}){
       return $session->{user_id_table};
    }
    my $fh;
    if(! open($fh,$session->{stub}.$session->getconf("exttable"))){
       $session->{user_id_table}=[];
       return $session->{user_id_table};
    }
    my @table=(); my $cnt = $session->getconf("max_id_no");
    while(<$fh>){
        chomp;
        push @table, $_;
        $cnt--;
        last if($cnt<=0);
    }
    close($fh);
    $session->{user_id_table}=\@table;
    return $session->{user_id_table};
}
sub write_user_id_table {
    my ($session,$table) = @_;
    my $file=$session->{stub}.$session->getconf("exttable");
    my $tmpfile = $session->mktemp();
    my $fh;
    if(!open($fh,">",$tmpfile)){
       print STDERR "Cannot create temporary file $tmpfile\n";
       return;
    }
    my $cnt=$session->getconf("max_id_no");
    foreach my $str (@$table){
        print $fh "",(defined($str) ? $str : ""),"\n";
        $cnt--;
        last if($cnt<=0);
    }
    close($fh);
    if(!rename($tmpfile,$file)){
        print STDERR "Cannot rename temp file to $file\n";
    }
}
# read/write constraints
sub _string_to_expr {
    my @v =split(',',shift);
    my $expr={};
    for (my $i=0;$i<scalar @v; $i+=2){
        $expr->{$v[$i]}=$v[$i+1];
    }
    return $expr;
}
sub read_user_constraints {
    my($session)=@_;
    if(defined $session->{user_constraints}){
        return $session->{user_constraints};
    }
    my $fh;
    if(! open($fh,$session->{stub}.$session->getconf("extconstr"))){
       $session->{user_constraints}=[];
       return $session->{user_constraints};
    }
    my @constr=();
    while(<$fh>){
        chomp;
        s/\"(.*)$//;
        my $raw=$1; $raw="" if(!defined $raw);
        my @v=split(/;/); my $text;
        next if(scalar @v < 4);
        if($v[0] eq "markov"){
            my @all=();
            for my $i(3..scalar @v-1){
                push @all,_string_to_expr($v[$i]);
            }
            $text = \@all;
        } else {
            $text=_string_to_expr($v[3]);
        }
        push @constr, {
            rel   => $v[0],
            skip  => $v[1],
            label => $v[2],
            text  => $text,
            raw   => $raw };
    }
    close($fh);
    $session->{user_constraints}=\@constr;
    return $session->{user_constraints};
}
sub write_user_constraints {
    my($session,$constr,$replace)=@_;
    if($replace){ $session->{user_constraints}=$constr; }
    my $file=$session->{stub}.$session->getconf("extconstr");
    my $tmpfile = $session->mktemp();
    my $fh;
    if(!open($fh,">",$tmpfile)){
       print STDERR "Cannot create temporary file $tmpfile\n";
       return;
    }
    foreach my $c (@$constr){
        print $fh "$c->{rel};$c->{skip};$c->{label}";
        if($c->{rel} eq "markov"){
            foreach my $e (@{$c->{text}}){
              print $fh ";";
              _print_expression($fh,$e);
            }
        } else {
            print $fh ";";
            _print_expression($fh,$c->{text});
        }
        print $fh "\"",$c->{raw},"\n";
    }
    close($fh);
    if(!rename($tmpfile,$file)){
        print STDERR "Cannot rename temp file to $file\n";
    }
}

# read/write history
sub read_user_history {
    my($session,$type)=@_;
    my $limit=$session->getconf("histsize");
    my $n=0; my $i=0;
    my $hist=[]; my $last="";
    my $fh;
    if(open($fh,"<",$session->{stub}.$session->getconf("exthis$type"))){
        while(<$fh>){
            chomp;
            next if($_ =~ /^$/ || $_ eq $last);
            $last=$_;
            $hist->[$i]=$last;
            $n++; $i++; $i=0 if($i>=$limit);
        }
        close($fh);
    }
    return { 
      hist  => $hist,
      limit => $limit,
      end   => $i,
      n     => $n>$limit ? $limit : $n,
    };
}

sub write_user_history {
    my($session,$type,$hist)=@_;
    if(ref($hist) ne "ARRAY"){
        return if($hist eq "");
        $hist=[$hist]; 
    } else {
        return if(scalar @$hist==0);
    }
    my $fh;
    use Fcntl ':flock';
    if(!open($fh,">>",$session->{stub}.$session->getconf("exthis$type"))){
        print STDERR "Cannot append to the history file " .
               $session->{stub}.$session->getconf("exthis$type")."\n";
        return;
    }
    flock($fh,LOCK_EX);
    foreach my $line(@$hist){
        chomp $line;
        $line =~ s/\n/ /gs;
        next if($line =~ /^\s*$/);
        print $fh "$line\n";
    }
    flock($fh,LOCK_UN);
    close($fh);
}

sub replace_expr_history {
    my($session,$hist)=@_;
    my $file=$session->{stub}.$session->getconf("exthis"."expr");
    my $tmpfile = $session->mktemp();
    my $fh;
    if(!open($fh,">",$tmpfile)){
       print STDERR "Cannot reopen temporary file $tmpfile\n";
       return;
    }
    foreach my $h (@$hist){
        print $fh "$h->[0],$h->[1],$h->[2],$h->[3]\n";
    }
    close($fh);
    if(!rename($tmpfile,$file)){
        print STDERR "Cannot rename temp file to $file\n";
    }
}

sub set_modified {
    my($session)=@_;
    return if($session->getconf("modified"));
    $session->setconf("modified","*");
    write_user_config($session);
}


1;


__END__ 

