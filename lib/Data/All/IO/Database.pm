package Data::All::IO::Database;

#   $Id: Database.pm,v 1.1.1.1 2005/05/10 23:56:20 dgrant Exp $


use strict;
use warnings;

use Data::All::IO::Base '-base';
use DBI;

our $VERSION = 0.16;

attribute '__DBH';
attribute '__STH';



sub open($)
{
    my $self = shift;
    my $query = $self->path()->[3];
    
    unless ($self->is_open())
    {
        #warn " -> Opening database connection for ", $self->ioconf()->{'perm'};
        #warn " -> path:", join ', ', @{ $self->path() };
        #warn " -> format:", $self->format()->{'type'};
        #warn " -> io:", $self->ioconf->{'type'};
        
        $self->_create_dbh();               #   Open DB connection
        if ($self->ioconf()->{'perm'} =~ /r/)
        {
            #warn " -> Executing query";
            
            my $sth = $self->__DBH()->prepare($query);
            $sth->execute() or die "Can't execute statement: $DBI::errstr";
            $self->__STH($sth);
            $self->_extract_fields();
        }
        
        $self->is_open(1);
    }
    
    return $self->is_open();
}

sub close()
{
    my $self = shift;

    $self->__STH()->finish()
    , $self->__DBH()->commit()     #   NOTE: uncomment this if autocommit = 0
        if ($self->__STH());

    $self->__DBH()->disconnect();
    $self->is_open(0);
    
    return;
}

sub nextrecord() { $_[0]->__STH()->fetchrow_hashref() }

sub getrecord_hash()
{
    my $self = shift; 
    my $sth = $self->__STH();

    return $sth->fetchrow_hashref();
}

sub getrecord_array() 
{ 
    my $self = shift; 
    my $record = $self->__STH()->fetchrow_arrayref();

    return !wantarray ? $record : @{ $record };
}

sub getrecords() 
{ 
    my $self = shift;
    
    return undef unless ($self->__STH()->rows);
    
    my (@records);
    while (my $ref = $self->__STH()->fetchrow_hashref())
    {
        push (@records, $ref);
    }

    return !wantarray ? \@records : @records;
    
}

sub putfields()
{
    my $self = shift;
    
    #   We don't do nothin' with fields for the database
    
    #   IDEA: Maybe we could use this call for creating a table
}


sub putrecord($;\%)
{
    my $self = shift;
    my ($record, $options) = @_;

    
    my @vars = $self->_generate_query_vars(
                            $options, $self->hash_to_array($record));
   
    #print join(':', @vars), "\n";
    
    $self->__STH($self->__DBH()->prepare($self->path()->[3]))
        unless $self->__STH();

    $self->__STH()->execute(@vars);
    
    return 1;
}


sub putrecords()
{
    my $self = shift;
    my ($records, $options) = @_;
    
    my $query = $self->path()->[3];

    
    die("$self->putrecords() needs records") unless ($#{ $records }+1);
        
    $self->__STH($self->__DBH()->prepare($query));
    
    my $record;
    foreach my $rec (@{ $records })
    {
        $self->putrecord($rec, $options);
    }
    
    #   Close the statement handle
    $self->__STH()->finish();
    
}

sub count()
#   TODO: Refactor this count() functionality.
#   What about INSERT queries. We could keep track of how many were
#   successfully inserted. 
{
    my $self = shift;
    my $query = $self->path()->[3];
    my ($sth, $ref, $count);
    
    return $count unless($self->ioconf()->{'perm'} =~ /^r/);
    
    $query =~ s/SELECT\s.+?\sFROM/SELECT COUNT(*) as cnt FROM/im;
    
    return undef unless ($sth = $self->__DBH()->prepare($query));
    
    $count = $self->__STH()->execute() or return undef;
    
    $self->__STH()->finish();
    
    return $count;
}





sub _generate_query_vars($$)
#   Create an ordered array of values to use in a DBI->execute() call to
#   replace '?' in the query.
{
    my $self = shift;
    my ($options, $vars) = @_;
    my @vars;
    
    #   TODO: Move arrayref checking to some form of option parser 
    
    if (defined($options->{'extra_pre_vars'}))
    {
        my @pre_vars = (ref($options->{'extra_pre_vars'}) eq 'ARRAY')
            ? @{ $options->{'extra_pre_vars'} }
            : ($options->{'extra_pre_vars'});
            
        #   Add the prefix values to the beginning of the array
        push(@vars, @pre_vars); 
    }
    
    #   Put the actual values into the array (in an INSERT, putrecord() will 
    #   send the ordered field values here)
    push(@vars, @{ $vars });
    
    #   Complete the array with the suffix values
    if (defined($options->{'extra_post_vars'}))
    {
        my @post_vars = (ref($options->{'extra_post_vars'}) eq 'ARRAY')
            ? @{ $options->{'extra_post_vars'} }
            : ($options->{'extra_post_vars'});
            
        #   Add the prefix values to the beginning of the array
        push(@vars, @post_vars); 
    }
         
    return wantarray ? @vars : \@vars; 
}

sub _create_dbh()
{
    my $self = shift;
    my $dbh = $self->__DBH() || $self->_db_connect();
    
    ($dbh)
        ? $self->__DBH($dbh)
        : die("Cannot create DB Connection");
        
    #$self->__DBH()->trace(2);
}

sub _create_sth()
{
    my $self = shift;
    my $sth = $self->__DBH()->prepare();
    
    ($sth)
        ? $self->__STH($sth)
        : die("Cannot prepare statement handle");
}

sub _db_connect()
{
    my $self = shift;
    return if ($self->is_open());
    #   NOTE: See line 53 if you want to set autocommit = 0
    return DBI->connect($self->_create_connect(), { PrintWarn=>1,PrintError=>1, RaiseError => 1, AutoCommit => 0 });
}

sub _create_connect()
{
    my $self = shift;
    return ($self->path()->[0],$self->path()->[1],$self->path()->[2]);
}

sub _extract_fields()
{
    my $self = shift;
    return if ($self->fields());
    
    $self->fields($self->__STH()->{'NAME'});
}



#   $Log: Database.pm,v $
#   Revision 1.1.1.1  2005/05/10 23:56:20  dgrant
#   initial import
#
#   Revision 1.1.2.2.2.2.2.1.6.1.8.27  2005/01/04 18:46:15  dgrant
#   *** empty log message ***
#
#   Revision 1.1.2.2.2.2.2.1.6.1.8.26  2004/08/12 18:40:47  dgrant
#   *** empty log message ***
#
#   Revision 1.1.2.2.2.2.2.1.6.1.8.24  2004/05/26 07:28:02  dgrant
#   *** empty log message ***
#
#   Revision 1.1.2.2.2.2.2.1.6.1.8.22  2004/05/20 17:43:41  dgrant
#   *** empty log message ***
#
#   Revision 1.1.2.2.2.2.2.1.6.1.8.21  2004/05/19 16:58:03  dgrant
#   *** empty log message ***
#
#   Revision 1.1.2.2.2.2.2.1.6.1.8.20  2004/05/17 23:27:17  dgrant
#   - Misc cleanup, no changes
#
#   Revision 1.1.2.2.2.2.2.1.6.1.8.19  2004/05/15 04:08:27  dgrant
#   *** empty log message ***
#
#   Revision 1.1.2.2.2.2.2.1.6.1.8.18  2004/05/13 00:23:56  dgrant
#   - Bug fix: count() was not returning results properly and now displays the
#   correct record count for read queries only
#
#   Revision 1.1.2.2.2.2.2.1.6.1.8.17  2004/05/12 03:34:55  dgrant
#   *** empty log message ***
#
#   Revision 1.1.2.2.2.2.2.1.6.1.8.16  2004/05/11 21:55:42  dgrant
#   - Bug fix: open() executed the query if it looked like a SELECT
#       instead of where ioconf said read or write. In postgresql, 
#       SELECTs can be used with functions for inserting which is a
#       write. 
#   
#   Revision 1.1.2.2.2.2.2.1.6.1.8.13  2004/05/10 16:29:50  dgrant
#   - Moved to version 0.026
#
#   Revision 1.1.2.2.2.2.2.1.6.1.8.8  2004/05/05 16:46:49  dgrant
#   - Misc changes I should have commited on Friday when I made them.
#
#   Revision 1.1.2.2.2.2.2.1.6.1.8.3  2004/04/28 23:51:43  dgrant
#   - Added transaction support
#
#   Revision 1.1.2.2.2.2.2.1.6.1  2004/04/08 23:08:56  dgrant
#   - Renamed getrecord() as getrecord_array()
#
#   Revision 1.1.2.2.2.2.2.1  2004/04/06 00:12:54  dgrant
#   - pre-011 version commit
#
#   Revision 1.1.2.2.2.2  2004/04/05 23:01:47  dgrant
#   - Database currently not working, but delim to delim is
#   - convert() works
#   - See examples/1 for working example
#
#   Revision 1.1.2.2.2.1  2004/03/31 22:36:26  dgrant
#   ongoing...

#   Revision 1.1.2.1  2004/03/26 21:36:53  dgrant
#   - Added IO::Database
#   - NOTE: Not currently functioning
#
#   Revision 1.1.1.1.2.1  2004/03/25 01:47:11  dgrant
#   - Initial import of modules
#   - Included CVS Id and Log variables
#   - Added use strict; to a few unlucky modules
#


1;