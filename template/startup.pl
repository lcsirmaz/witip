## startup perl routine for witip
##
## Automatically generated from the template
##

use lib '@INSTALLDIR@/perl_lib';

use Carp qw(verbose);
use Apache2::RequestUtil;
use Apache2::Request;

use wAboutPage;
use wAnApache;
use wConfigPage;
use wConstrPage;
use wConstr;
use wDefault;
use wExpr;
use wHtml;
use wLoginPage;
use wLogoutPage;
use wMacrosPage;
use wMacros;
use wMainPage;
use wMakelp;
use wParser;
use wPrintPage;
use wSession;
use wUtils;
use wZip;

use strict;
$SIG{__WARN__} = \&Carp::cluck;

print STDERR "Witip core routines loaded\n";


1;

