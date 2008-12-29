package Data::All::Format::Delim;


#   $Id: Delim.pm,v 1.1.1.1 2005/05/10 23:56:20 dgrant Exp $

#   TODO: fully implement add_quotes attribute

use strict;
use warnings;

use Data::All::Format::Base '-base';
use Text::ParseWords qw(quotewords);

use vars qw(@EXPORT $VERSION);

@EXPORT = qw();
$VERSION = 0.10;

attribute 'delim'   => ',';
attribute 'quote'   => '"';
attribute 'escape'  => '\\';
attribute 'break'   => "\n";
attribute 'add_quotes' => 1;


sub expand($);
sub contract(\@);


sub expand($)
#   TODO: There are likely better ways to do this. Iterate through 
#   each character? This way is too complex and likely buggy. (slow?) 
{
    my ($self, $raw) = @_;
    my $record = $raw;
    
    $record =~ s/\"\"(..)\'\'/$1/;
    #   BUG: in Text::Parsewords work around
    $record =~ s/'/\\'/g if ($raw =~ /'/);
    
    my $values = $self->parse(\$record);
    
    return !wantarray ? $values : @{ $values };
}

sub parse(\$)
{
    my ($self, $record) = @_;
    my @values;
    
    my ($d, $q, $e) = ($self->delim, $self->quote, $self->escape);
    
    @values = quotewords($d,0, $$record);
    
    return \@values;
}

sub parse3(\$)
{
    my ($self, $record) = @_;
    my @values;
    
#    my ($d, $q, $e) = ($self->delim, $self->quote, $self->escape);
    
    #use Regexp::Common qw /delimited/;
    #while ($$record =~ /$RE{delimited}{-delim=>quotemeta($d)}{-keep}/g)
    #{
    #    push (@values, $1);
    #}
    
    
        
    
    #warn Dumper(\@values);
    #return \@values;
}

sub parse2(\$)
#   A bad solution, CSV only!
{
    my ($self, $record) = @_;
    my @values;
    
    my ($d, $q, $e) = ($self->delim, $self->quote, $self->escape);
   
    #   From: http://xrl.us/bvci (Experts Exchange)
    push (@values, $+) while $$record =~ m{
      "([^\"\\]*(?:\\.[^\"\\]*)*)",?  # groups the phrase inside the quotes
    | ([^,]+),?
    | ,
    }gx;
    
    push(@values, '') if substr($$record,-1,1) eq $d;

    
    return \@values;
}

sub contract(\@)
{
    my ($self, $values) = @_;
    my @values;

    my $d = $self->delim;
    my $q = $self->quote;
    my $e = $self->escape;

    foreach (@{ $values })
    {
        $_ ||= '';
        
        $_ =~ s/$q/$e.$q/gx
            if ($q);            #   Escape quotes with the values
     
        ($self->add_quotes())
            ? push(@values, "$q$_$q")     #   Add quotes...
            : push(@values, $_);        #   ...for alphanumeric strings only
    }

    return CORE::join($d, @values).$self->break;
}














#   $Log: Delim.pm,v $
#   Revision 1.1.1.1  2005/05/10 23:56:20  dgrant
#   initial import
#
#   Revision 1.1.1.1.8.9  2004/08/25 23:17:51  dgrant
#   - Changed default line break to "\n" rather than '\n'
#
#   Revision 1.1.1.1.8.8  2004/08/12 18:40:46  dgrant
#   *** empty log message ***
#
#   Revision 1.1.1.1.8.4  2004/05/17 23:27:17  dgrant
#   - Misc cleanup, no changes
#
#   Revision 1.1.1.1.8.3  2004/04/24 01:22:35  dgrant
#   - Added CPAN documentation to Data::All and updated the examples to be
#   distribution friendly
#
#   Revision 1.1.1.1.8.2  2004/04/16 19:04:03  dgrant
#   - Fixed  bug in contract() which tried to escape non-existant quotes
#
#   Revision 1.1.1.1.8.1  2004/04/16 17:10:33  dgrant
#   - Merging libperl-016 changes into the libperl-1-current trunk
#
#   Revision 1.1.1.1.2.1.2.1.2.1.16.3.4.3  2004/04/15 23:50:38  dgrant
#   - Changed Format::Delim to use Text::Parsewords (again). There
#     is a bug in Text::Parsewords that causes it to bawk when a
#     ' (single quote) character is present in the string (BOO!).
#     I wrote a temp work around (replace it with \'), but we will
#     need to do something about that.
#
#   Revision 1.1.1.1.2.1.2.1.2.1.16.3.4.2  2004/04/15 23:15:24  dgrant
#   *** empty log message ***
#
#   Revision 1.1.1.1.2.1.2.1.2.1.16.3.4.1  2004/04/13 22:26:32  dgrant
#   - Fixed prototype mismatch for expand()
#
#   Revision 1.1.1.1.2.1.2.1.2.1.16.3  2004/04/08 23:08:56  dgrant
#   - Renamed getrecord() as getrecord_array()
#
#   Revision 1.1.1.1.2.1.2.1.2.1.16.2  2004/04/08 18:24:35  dgrant
#   - Delim now uses a better regexp for parsing lines
#   - Renamed getrecord() to getrecord_array()
#
#   Revision 1.1.1.1.2.1.2.1.2.1.16.1  2004/04/08 16:43:08  dgrant
#   - In the midst of changes mainly for upgrading the delimited functionality
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