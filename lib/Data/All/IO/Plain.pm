package Data::All::IO::Plain;

#   $Id: Plain.pm,v 1.1.1.1 2005/05/10 23:56:20 dgrant Exp $

#   BUG: A leading delimiter (i.e. a blank first column) will fuck it up

use strict;
use warnings;

use Data::All::IO::Base '-base';
use IO::All;
use FileHandle;


our $VERSION = 0.12;

internal 'IO';
internal 'fh';

sub create_path()
{
    my $self = shift;
    return join '', @{ $self->path };
}

sub open($)
{
    my $self = shift;
    my $path = $self->create_path();
    
    unless ($self->is_open())
    {
        #warn " -> Opening $path for ", $self->ioconf()->{'perm'};
        #warn " -> path:", join ', ', @{ $self->path() };
        #warn " -> format:", $self->format()->{'type'};
        #warn " -> io:", $self->ioconf->{'type'};
    
        die("The file: $path does not exist")
            if (($self->ioconf()->{'perm'} eq 'r') && !(-f $path));
    
        #   We create out own filehandle for better read/write control
        my $fh = FileHandle->new($self->create_path(), $self->ioconf()->{'perm'});        
        my $IO = io(-file_handle => $fh, '-tie');
         
        $IO->autoclose(1);
        
        $self->__IO( $IO );
        $self->__fh( $fh );
        
        $self->is_open(1);
    
        $self->_extract_fields();             #   Initialize field names
    }
    
    return $self->is_open();
}

sub close()
{
    my $self = shift;
    
    $self->__IO()->close();
    $self->is_open(0);
}

sub nextrecord() 
{  
    my $self = shift;
    my $r;
    
    #   TODO: Write an actual solution for converting from
    #   one line terminator to another.

    #   Incrememnt cursor and remove trailing line
    if ($r = $self->__IO()->getline())
    {  
        $r =~ s/\r\n/\n/g;      #   NOTE: a quick hack to convert DOS to UNIX
        chomp($r);  
        $self->_next();
    }
    
    return $r;
}

sub hash_to_record()
{
    my ($self, $hash) = @_;
    #   we do it like this to make sure the order is the same
    return $self->array_to_record($self->hash_to_array($hash));
}

sub array_to_record()
{
    my ($self, $array) = @_;
    return $self->__FORMAT()->contract($array);
}

sub getrecord_array() 
#   With original = include original record from file
{ 
    my ($self, $with_original) = @_;
    my $raw;
    
    return undef unless ($raw = $self->nextrecord());
    
    #   We return the original record first b/c if we do it
    #   last and there are empty values at the end the order will be confused
    my $rec_arrayref = ($with_original)
        ? [$raw, $self->__FORMAT()->expand($raw)]
        : [$self->__FORMAT()->expand($raw)];
    
    return !wantarray ? $rec_arrayref : @{ $rec_arrayref };
}
 
sub putfields()
{
    my $self = shift;
    $self->__IO()->print($self->array_to_record($self->fields));
}

sub putrecord($)
{
    my $self = shift;
    my $record = shift;

    $self->__IO()->print($self->hash_to_record($record));
    
    return 1;
}


sub _extract_fields()
{
    my $self = shift;
    return if ($self->fields());
    $self->fields([$self->getrecord_array(0)]);
}

sub count()     
{ 
    my $self = shift;
    my $count;
    
    #   From the Perl Cookbook. It doesn't actually replace every
    #   new line with a new new line -- it's a legacy feature. 
    $count += tr/\n/\n/ while sysread($self->__fh(), $_, 2 ** 20);
    
    return $count;
}
sub _next()      { $_[0]->__curpos( $_[0]->__curpos() + 1) }

#   $Log: Plain.pm,v $
#   Revision 1.1.1.1  2005/05/10 23:56:20  dgrant
#   initial import
#
#   Revision 1.1.2.1.2.1.2.1.6.2.4.1.4.17  2005/01/04 18:46:15  dgrant
#   *** empty log message ***
#
#   Revision 1.1.2.1.2.1.2.1.6.2.4.1.4.16  2004/08/12 18:40:48  dgrant
#   *** empty log message ***
#
#   Revision 1.1.2.1.2.1.2.1.6.2.4.1.4.14  2004/05/20 17:45:09  dgrant
#   - Added Data::All::store()
#   - Some bug fixes
#
#   Revision 1.1.2.1.2.1.2.1.6.2.4.1.4.13  2004/05/20 17:43:41  dgrant
#   *** empty log message ***
#
#   Revision 1.1.2.1.2.1.2.1.6.2.4.1.4.12  2004/05/17 23:27:17  dgrant
#   - Misc cleanup, no changes
#
#   Revision 1.1.2.1.2.1.2.1.6.2.4.1.4.10  2004/05/13 00:23:11  dgrant
#   - Some minor comments added
#
#   Revision 1.1.2.1.2.1.2.1.6.2.4.1.4.9  2004/05/11 01:49:33  dgrant
#   *** empty log message ***
#
#   Revision 1.1.2.1.2.1.2.1.6.2.4.1.4.8  2004/05/10 16:29:50  dgrant
#   - Moved to version 0.026
#
#   Revision 1.1.2.1.2.1.2.1.6.2.4.1.4.6  2004/05/06 15:47:45  dgrant
#   *** empty log message ***
#
#   Revision 1.1.2.1.2.1.2.1.6.2.4.1.4.3  2004/04/29 22:03:22  dgrant
#   - Added count() functionality exposed through Data:All so we can get the
#   line count in files and the COUNT(*) for SELECT queries
#   - Fixed a database disconnection bug (caused queries to rollback)
#   - Statement handled are now finished too
#
#   Revision 1.1.2.1.2.1.2.1.6.2.4.1.4.2  2004/04/21 23:01:13  dgrant
#   - Added a quick fix for converting DOS line enders to UNIX. This will need
#   to be reworked into a final solution.
#
#   Revision 1.1.2.1.2.1.2.1.6.2.4.1.4.1  2004/04/16 20:45:04  dgrant
#   *** empty log message ***
#
#   Revision 1.1.2.1.2.1.2.1.6.2.4.1  2004/04/15 23:15:24  dgrant
#   *** empty log message ***
#
#   Revision 1.1.2.1.2.1.2.1.6.2  2004/04/08 18:24:36  dgrant
#   - Delim now uses a better regexp for parsing lines
#   - Renamed getrecord() to getrecord_array()
#
#   Revision 1.1.2.1.2.1.2.1.6.1  2004/04/08 16:43:09  dgrant
#   - In the midst of changes mainly for upgrading the delimited functionality
#
#   Revision 1.1.2.1.2.1.2.1  2004/04/06 00:12:54  dgrant
#   - pre-011 version commit
#
#   Revision 1.1.2.1.2.1  2004/04/05 23:01:47  dgrant
#   - Database currently not working, but delim to delim is
#   - convert() works
#   - See examples/1 for working example
#
#   Revision 1.1.2.1  2004/03/30 22:43:11  dgrant
#   - Renamed to Data::All::IO::Plain
#
#   Revision 1.1.2.2  2004/03/26 21:38:39  dgrant
#   *** empty log message ***
#
#   Revision 1.1.2.1  2004/03/25 20:25:11  dgrant
#   - Moved File.pm to FlatFile.pm
#
#   Revision 1.1.1.1.2.1  2004/03/25 01:47:11  dgrant
#   - Initial import of modules
#   - Included CVS Id and Log variables
#   - Added use strict; to a few unlucky modules
#


1;