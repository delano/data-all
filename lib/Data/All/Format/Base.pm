package Data::All::Format::Base;

#   Base package for all format modules

#   $Id: Base.pm,v 1.1.1.1 2005/05/10 23:56:20 dgrant Exp $

use strict;
use warnings;


use Data::All::Base '-base';                            #   Spiffy


our $VERSION = 0.10;

attribute 'type';

sub init()
{
    my $self = shift;
    populate( $self => $_[0] );
    return $self;
}






#   $Log: Base.pm,v $
#   Revision 1.1.1.1  2005/05/10 23:56:20  dgrant
#   initial import
#
#   Revision 1.1.1.1.8.3  2004/08/12 18:40:46  dgrant
#   *** empty log message ***
#
#   Revision 1.1.1.1.8.1  2004/04/16 17:10:33  dgrant
#   - Merging libperl-016 changes into the libperl-1-current trunk
#
#   Revision 1.1.1.1.2.1.2.1.2.1  2004/04/05 23:01:46  dgrant
#   - Database currently not working, but delim to delim is
#   - convert() works
#   - See examples/1 for working example
#
#   Revision 1.1.1.1.2.1.2.1  2004/03/26 21:38:38  dgrant
#   *** empty log message ***
#
#   Revision 1.1.1.1.2.1  2004/03/25 01:47:10  dgrant
#   - Initial import of modules
#   - Included CVS Id and Log variables
#   - Added use strict; to a few unlucky modules
#

1;

