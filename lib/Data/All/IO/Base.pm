package Data::All::IO::Base;

#   Base package for all format modules

#   $Id: Base.pm,v 1.1.1.1 2005/05/10 23:56:20 dgrant Exp $

use strict;
use warnings;

use Data::All::Base '-base';                            #   Spiffy
use Data::All::Format;

our $VERSION = 0.12;

#   Interface
sub count();
sub array_to_hash(\@);

attribute 'format';
attribute 'fields';
attribute 'ioconf';
attribute   'path';

attribute 'is_open'             => 0;

sub _add_field()
{
    my ($self, $name) = @_;
    
    return if (defined($self->__added_fields()->{'_ORGINAL'}));
    
    unshift(@{ $self->fields() }, '_ORIGINAL');
    $self->__added_fields()->{'_ORGINAL'}++;
}

sub array_to_hash(\@)
{
    my ($self, $record) = @_;
    my %hash;
    
    $self->_add_field('_ORIGINAL') if ($self->ioconf->{'with_original'});
        
    my @fields = @{ $self->fields() };
    @hash{ @fields } = @{ $record };
    
    return \%hash;
}

sub hash_to_array()
{
    my ($self, $hash) = @_;
    return [@{ $hash }{@{ $self->fields() }}];
}


sub getrecord_hash()
{
    my $self = shift;
    my $rec = $self->getrecord_array($self->ioconf->{'with_original'});

    return ($rec)
        ?  $self->array_to_hash($rec)
        : undef;
}

sub getrecords(;$$)
{
    my $self = shift;
    #   TODO:   Enable running COUNT records only

    my (@records);
    
    #warn ' -> using fields:', join(',', @{ $self->fields });
    
    while (my $record = $self->getrecord_hash())
    { 
        push(@records, $record);
    }
    
    return wantarray ? @records : \@records;
}



sub putrecords()
{
    my $self = shift;
    my ($records, $options) = @_;

    my $start = 0;
    my $count = $#{ $records }+1;

    die("$self->putrecords() needs records") unless ($#{ $records }+1);
        
    #warn "Writing $count records from $start";
    
    my $record;
    while ($count--)
    {
        $self->putrecord($records->[ $start++ ], $options);
    }
}


sub _load_format()
{
    my $self = shift;
    my $format = shift || $self->format();
    
    return Data::All::Format->new($format->{'type'}, $format);
}


sub init()
#   Called in Data::All::IO::new
#   TODO: Create Format::Hash
{
    my ($self, $args) = @_;
    
    populate $self => $args;
    
    $self->__FORMAT($self->_load_format())  
        #   Override the loading of a Format reader for Hash types
        unless ($self->ioconf()->{'type'} eq 'db');
    
    return $self;
}

internal 'FORMAT';
internal 'curpos'               => -1;
internal 'added_fields'         => {};


#   $Log: Base.pm,v $
#   Revision 1.1.1.1  2005/05/10 23:56:20  dgrant
#   initial import
#
#   Revision 1.1.1.1.8.13  2005/01/04 18:46:15  dgrant
#   *** empty log message ***
#
#   Revision 1.1.1.1.8.12  2004/08/12 18:40:47  dgrant
#   *** empty log message ***
#
#   Revision 1.1.1.1.8.8  2004/05/20 17:43:40  dgrant
#   *** empty log message ***
#
#   Revision 1.1.1.1.8.7  2004/05/10 04:10:05  dgrant
#   *** empty log message ***
#
#   Revision 1.1.1.1.8.6  2004/05/06 15:47:45  dgrant
#   *** empty log message ***
#
#   Revision 1.1.1.1.8.4  2004/04/29 22:03:21  dgrant
#   - Added count() functionality exposed through Data:All so we can get the
#   line count in files and the COUNT(*) for SELECT queries
#   - Fixed a database disconnection bug (caused queries to rollback)
#   - Statement handled are now finished too
#
#   Revision 1.1.1.1.8.3  2004/04/28 22:50:47  dgrant
#   - Added the option to process files record by record rather than atomically
#
#   Revision 1.1.1.1.8.1  2004/04/16 17:10:34  dgrant
#   - Merging libperl-016 changes into the libperl-1-current trunk
#
#   Revision 1.1.1.1.2.1.2.3.2.2.2.1.6.2.4.1  2004/04/15 23:15:24  dgrant
#   *** empty log message ***
#
#   Revision 1.1.1.1.2.1.2.3.2.2.2.1.6.2  2004/04/08 18:24:36  dgrant
#   - Delim now uses a better regexp for parsing lines
#   - Renamed getrecord() to getrecord_array()
#
#   Revision 1.1.1.1.2.1.2.3.2.2.2.1.6.1  2004/04/08 16:43:09  dgrant
#   - In the midst of changes mainly for upgrading the delimited functionality
#
#   Revision 1.1.1.1.2.1.2.3.2.2.2.1  2004/04/06 00:12:54  dgrant
#   - pre-011 version commit
#
#   Revision 1.1.1.1.2.1.2.3.2.2  2004/04/05 23:01:47  dgrant
#   - Database currently not working, but delim to delim is
#   - convert() works
#   - See examples/1 for working example
#
#   Revision 1.1.1.1.2.1.2.3  2004/03/30 22:43:29  dgrant
#   *** empty log message ***
#
#   Revision 1.1.1.1.2.1.2.2  2004/03/26 21:38:39  dgrant
#   *** empty log message ***
#
#   Revision 1.1.1.1.2.1  2004/03/25 01:47:11  dgrant
#   - Initial import of modules
#   - Included CVS Id and Log variables
#   - Added use strict; to a few unlucky modules
#

1;

