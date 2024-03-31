#################
## wAnApache.pm
#################
##
## Load appropriate Apache Module
##
###########################################################################
# This code is part of wITIP (a web based Information Theoretic Prover)
#
# Copyright 2017-2024 Laszlo Csirmaz, UTIA, Prague
# This program is free, open-source software. You may redistribute it
# and/or modify under the terms of the GNU General Public License (GPL).
# There is ABSOLUTELY NO WARRANTY, use at your own risk.
###########################################################################

package wAnApache;
BEGIN
{
        use Exporter;
        our (@ISA, @EXPORT );
        @ISA     = qw(Exporter);
        @EXPORT  = qw(OK NOT_FOUND);
}
use strict;

eval "require ModPerl::Registry"; if( $@ ) { die $@; }
eval "require Apache2::Const; import Apache2::Const;"; if( $@ ){ die $@; }

1;

__END__

=pod

=head1 wITIP perl modules

=head2 wAnApache.pm

Load modperl registry module and Apache2 constants OK and NOT_FOUND.

=cut

