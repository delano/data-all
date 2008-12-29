package Data::All::Format::XML;


#   $Id: XML.pm,v 1.1.1.1 2005/05/10 23:56:20 dmandelbaum Exp $


use strict;
use warnings;

use Data::All::Format::Base;

use vars qw(@EXPORT $VERSION);

@EXPORT = qw();
$VERSION = 0.10;

use base 'Exporter';
our @EXPORT = qw(new internal attribute populate error init	_load_format);

attribute 'format'  => '';
attribute 'encoding' => '';


sub expand($);
sub contract(\@);




sub expand($)
{
    my $self = shift;
    my $record = shift;
    my $template = $self->pack_template();
    
    return unpack($template, $record);
}

sub contract(\@)
{
    my $self = shift;
    my $values = shift;
    my $template = $self->pack_template();
    
    return pack($template, @{ $values });
}


sub pack_template()
{
    my $self = shift;
    my @template;
    
    foreach my $e (@{ $self->lengths })
    {
        push(@template, "A$e");
    }
    
    return !wantarray ? join(' ', @template) : @template; 
}













#   $Log: XML.pm,v $
#   Revision 1.1.1.1  2005/05/10 23:56:20  dmandelbaum
#   initial import
#
#   Revision 1.1.1.1.8.3  2004/08/12 18:40:47  dmandelbaum
#   *** empty log message ***
#
#   Revision 1.1.1.1.8.1  2004/04/16 17:10:34  dmandelbaum
#   - Merging libperl-016 changes into the libperl-1-current trunk
#
#   Revision 1.1.1.1.2.1  2004/03/25 01:47:11  dmandelbaum
#   - Initial import of modules
#   - Included CVS Id and Log variables
#   - Added use strict; to a few unlucky modules
#

1;