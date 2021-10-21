#!/usr/bin/perl -W
# installing wITIP
#

use strict;

sub user_input {
    my($regexp,$prompt,$default)=@_;
    $prompt="" if(!defined $prompt);
    while(1){
       print "  ",$prompt,":\n      ";
       print "[$default] " if($default);
       print "? ";
       my $in=<STDIN>;
       chomp $in;
       if($in eq "" && defined($default)){
          return $default;
       }
       return $in if($in =~ m#^$regexp$#);
       print "  Wrong input format, please try again.\n";
    }
}

# figure out where this program is
sub installdir {
    # should start with /
    my $prog=$0;
    if($prog =~ m#^/#){ # full path
        $prog =~ s#/bin/install.pl$##;
        return $prog;
    }
    my $thisdir=`/bin/pwd`; chomp $thisdir;
    $prog =~ s/install.pl$//;
    while($prog =~ s#([^/]+)/##){
        my $what=$1; 
        next if($what eq ".");
        if($what eq ".."){
           $thisdir =~ s#/[^/]+$##;
           next;
        }
        $thisdir .= "/$what";
    }
    $thisdir =~ s#/bin$##;
    return $thisdir;
}

# prompt for the installation directory
sub get_installdir {
    my $suggest=installdir();
    my $dir="";
    while($dir eq "" || $dir !~ m#^/# || !-d $dir){
      $dir=user_input("\\/[\\w\\/:\\+\\-,%]+",
        "Please specify the full path where wITIP has been unpacked to",$suggest);
      $dir =~ s#/$##g;
      if($dir && ! -d "$dir/config"){ mkdir "$dir/config"; }
      foreach my $subdir (qw( bin config html html/css html/js html/images perl_lib prog template w )){
          if($dir && ! -d "$dir/$subdir"){
             print "The directory \"$dir\" seem not to be correct ($dir/$subdir is missing).\n";
             $dir="";
          }
      }
      if($dir && ! -e "$dir/prog/glpksolve.c"){
         print "The directory \"$dir\" seems not to be correct.\n";
         $dir="";
      }
    }
    print "OK, using $dir.\n\n";
    return $dir;
}

#change permission for the data directory
sub change_ddir_permission {
    my ($ddir)=@_;
    mkdir $ddir if(! -d $ddir);
    return 1  if(!-d $ddir);
    chmod 0777, $ddir;
    if(((stat $ddir)[2] & 0777) != 0777){
       print "Cannot change the permissions of the directory $ddir.\n";
       return 1;
    }
    # check permissions along the whole path ...
    while(1) {
        $ddir =~ s#/[^/]*$##;
        last if($ddir eq "");
        if(((stat $ddir)[2]& 0555) != 0555){
           print "The parent directory $ddir is not accessible by the apache process.\n";
           return 1;
        }
    }
    return 0;
}

# get data directory
sub get_datadir_aux {
    my ($idir)=@_;
    my $ddir="$idir/data";
    print "The full path of the directory where web user data will be stored. 
Its permissions will be changed so that anyone can write and create files
here. Later you can change the permissions to restrict it to the web server only.
The whole path is checked for accessibility.\n";
    my $udir=user_input("\\/[\\w\\/:\\+\\-,%]+",
        "Web user data directory (full path)",$ddir);
    $udir =~ s#/$##g;
    if(! -d $udir){
        my $yes=user_input("(yes|no)",
        "The directory $udir does not exist. Create it (yes/no)?","yes");
        if($yes eq "yes"){
            use File::Path qw(make_path);
            make_path($udir);
        } else {
            return "";
        }
    }
    return "" if(! -d $udir);
    if(change_ddir_permission($udir)){ return ""; }
    return $udir;
}

sub get_datadir {
    my($idir)=@_;
    my $udir="";
    while($udir eq ""){
       $udir=get_datadir_aux($idir);
    }
    print "Using $udir as the data directory.\n\n";
    return $udir;
}

# compile the glpksolve helper program
sub compile {
    my ($instdir,$edir)=@_;
    if(-x "$edir/glpksolve"){
        print "The executable `glpksolve' was found in the $edir directory.\n";
        my $ok=user_input("(yes|no)","Is it OK to use (yes/no)?","yes");
        return if($ok eq "yes");
    }
    if(! -e "$instdir/prog/glpksolve.c"){
        die "
Cannot find the source file in $instdir/prog. Please make sure that
all wITIP files have been extracted correctly.\n";
    }
    if(! -e "/usr/include/glpk.h"){
        die "
wITIP uses the glpk binaries, and did not find the glpk header
file in the standard place. Please install glpk from the 
libglpk-dev package before continuing.\n";
    }
    my $gcc=`which gcc`; chomp $gcc;
    if(!$gcc){
        print "The C compiler `gcc' was not found.\n";
        $gcc=user_input("[\\w\\.\\-\\+%:]+","C complier to use","cc");
    }
    unlink "$edir/glpksolve"; # if it was there
    system("$gcc -O3 -o $edir/glpksolve $instdir/prog/glpksolve.c -lglpk 2>/dev/null");
    if($?<0 || ($?>>8)!=0 || !-e "$edir/glpksolve"){
        print STDERR "Cannot compile glpksolve. Please try to do it manually, and retry.\n";
        die "To compile it, use:
  gcc -O3 -o glpksolve -I<includedir> prog/blpksolve.c -l<glpklibrary>
where <includedir> contains the glpk.h header, and <glpklibrary> is the
glpk library file without the .so extension.\n";
    }
}

sub get_exedir_aux {
    my($idir)=@_;
    my $ddir="$idir/bin";
    my $edir=user_input("\\/[\\w\\/:\\+\\-,%]+",
        "Directory where the LP solver `glpksolve' will be compiled",$ddir);
    $edir =~ s#/$##g;
    if(! -d $edir){
        my $yes=user_input("(yes|no)",
        "The directory $edir does not exist. Should I create it (yes/no)?","yes");
        if($yes eq "yes"){
            use File::Path qw(make_path);
            make_path($edir);
        } else {
            return "";
        }
    }
    return "" if(! -d $edir);
    return $edir;
}
    
sub get_lpsolver {
    my($idir)=@_; my $edir="";
    while($edir eq ""){
       $edir=get_exedir_aux($idir);
    }
    print "Using $edir/glpksolve as the LP solver program.\n\n";
    # compile it ...
    compile($idir,$edir);
    return "$edir/glpksolve";
}

# get helper program
sub which_program {
    my($prog)=@_;
    my $res=`which $prog`; chomp $res;
    return $res;
}

sub redefine_helpers {
    my %P=();
    foreach my $prog (qw( mktemp zip unzip file )){
       $P{$prog}=which_program($prog);
       if(!$P{$prog}){
           print "Program `$prog' was not found. Please specify it using the full path\n";
           $P{$prog}=user_input("\\/[\\w\\/:\\+\\-,%]+",
             "Program `$prog' with full path");
       } else {
           $P{$prog}=user_input("\\/[\\w\\/:\\+\\-,%]+",
             "Program `$prog' with full path",$P{$prog});
       }
    }
    print "Using helper programs
        $P{mktemp}
        $P{zip}
        $P{unzip}
        $P{file}\n\n";
    return ($P{mktemp},$P{zip},$P{unzip},$P{file});
}

sub virtual_host {
    return user_input("[\\w:\\-\\*]+",
       "The name of the virtual host. If unsure, use the default","*");
}
sub apache_port {
    return user_input("[1-9][0-9]*",
       "The http server port","80");
}
sub get_site_name {
    my($port)=@_;
    my $ex= $port eq "80" ? "" : ":$port";
    print "Congifure the URL path of wITIP. If your site is dedicated solely
to wITIP, then this should be \"/\". Otherwise this is the path
(starting with a slash) which leads to wITIP's opening page. Probably it
is just \"/witip\".\n";
    return user_input("^\\/[\\w\\/:\\.\\-]*",
      "wITIP URL path (that comes after http://YOUR-SITE$ex)","/witip");
}
# replace a line with the configured values
sub replace_config {
    my($text,$conf)=@_;
    foreach my $k( keys %$conf ){
       $text =~ s/\@$k\@/$conf->{$k}/ge;
    }
    return $text;
}

##################################################

# ask questions for the installation
print "Configuring wITIP\n\n";

my $CONFIG={
  INSTALLDIR => "",  # base directory where witip is installed
  BASEDIR    => "",  # data directorye for user data
  LPSOLVER   => "",  # the glpk based lp solver
  MKTEMP     => "",  # helper programs
  ZIP        => "",
  UNZIP      => "",
  FILETYPE   => "",
  HOST       => "",  # vitual host
  PORT       => "",  # port
  BASEHTML   => "",  # prefix to the witip pages
};

print "Directories:\n";
$CONFIG->{INSTALLDIR} = get_installdir();
$CONFIG->{BASEDIR}    = get_datadir($CONFIG->{INSTALLDIR});
$CONFIG->{LPSOLVER}   = get_lpsolver($CONFIG->{INSTALLDIR});
print "Helper programs: mktemp, zip, unzip, and file\n";
($CONFIG->{MKTEMP},$CONFIG->{ZIP},$CONFIG->{UNZIP},$CONFIG->{FILETYPE})
                      = redefine_helpers();
print "Web server configuration\n";
$CONFIG->{HOST}       = virtual_host();
$CONFIG->{PORT}       = apache_port();
$CONFIG->{BASEHTML}   = get_site_name($CONFIG->{PORT});
print "Using virtual host $CONFIG->{HOST}, port $CONFIG->{PORT}",
      " and URL path $CONFIG->{BASEHTML}.\n\n";

##################################################
# print out all configuration parameters, 
# and ask if it is to configure
print "You have chosen the following configuration values. Please check
them carefully.\n\n",
"installation directory:  $CONFIG->{INSTALLDIR}\n",
"user data directory:     $CONFIG->{BASEDIR}\n",
"LP solver program:       $CONFIG->{LPSOLVER}\n",
"Helper programs:         $CONFIG->{MKTEMP}\n",
"                         $CONFIG->{ZIP}\n",
"                         $CONFIG->{UNZIP}\n",
"                         $CONFIG->{FILETYPE}\n",
"virtual host:            $CONFIG->{HOST}\n",
"port:                    $CONFIG->{PORT}\n",
"URL path:                $CONFIG->{BASEHTML}\n";
print "\n";
"yes" eq user_input("(yes|no)",
   "Proceed with generating configuration-dependent files (yes/no)","yes") || 
   die "Please rerun install.pl to configure wITIP.\n";

my $templates = [
{ template => "apache.conf", goal => "config/apache.conf"  },
{ template => "startup.pl",  goal => "bin/startup.pl"      },
{ template => "index.html",  goal => "html/index.html"     },
{ template => "wDefault.pm", goal => "perl_lib/wDefault.pm"}
];

foreach my $tmp (@$templates){
   print "Configuring ",$tmp->{goal},"\n";
   my ($ih,$oh);
   open($ih,"<","$CONFIG->{INSTALLDIR}/template/".$tmp->{template}) ||
      die "Cannot open template for ".$tmp->{goal}."\n";
   open($oh,">","$CONFIG->{INSTALLDIR}/".$tmp->{goal}) ||
      die "Cannot create goal file ".$tmp->{goal}."\n";
   while(<$ih>){
      print $oh "",replace_config($_,$CONFIG);
   }
   close($ih); close($oh);
}
# create link to index.htm
link "$CONFIG->{INSTALLDIR}/html/index.html", "$CONFIG->{INSTALLDIR}/html/index.htm";

print "\nYou have configured wITIP. To go online add the line
   Include $CONFIG->{INSTALLDIR}/config/apache.conf
to apache config and restart apache. Make sure that apache is
configured with the perl module enabled\n";

exit 0;

