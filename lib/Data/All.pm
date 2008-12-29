package Data::All;

#   Data::All - Access to data in many formats from many places

#   $Id: All.pm,v 1.1.1.1 2005/05/10 23:56:20 dgrant Exp $

#   TODO: Create Data::All::IO::Hash for internal storage
#   TODO: Add checking for output field names that aren't present in input field names
#   TODO: Auto reset file/db cursors? Call read() then convert() causes error;

use strict;
use warnings;
#use diagnostics;
 
use Data::All::Base '-base';    #   Spiffy
use Data::All::IO;

our $VERSION = 0.036;
our @EXPORT = qw(collection);


##  Interface
sub show_fields;    #   returns an arrayref of field names
sub collection;     #   A shortcut for open() and read()
sub getrecord;
sub putrecord;
sub is_open;
sub convert;        #   Change formats
sub store;          #   save in memory records
sub count;          #   Record count
sub close;
sub read;
sub open;


##  External Structure
attribute         'from';
attribute           'to';
attribute 'print_fields'        => 0;
attribute       'atomic'        => 0;



#   INTERNAL ATTRIBUTES
sub internal;

#   Contains Data::All::IO::* object by moniker
internal 'collection'        => {};  

internal 'profile'     =>      
#   Hardcoded/commonly used format configs
{
    csv     => ['delim', "\n", ',', '"', '\\'],
    tab     => ['delim', "\n", "\t", '', '']
};

internal 'a2h_template'  =>    
#   Templates for converting arrayref configurations to 
#   internally used, easy to handle hashref configs. See _parse_args().
#   TODO: move this functionality into a generic arg parsing library
{
    'format.delim'      => ['type','break','delim','quote','escape'],
    'format.fixed'      => ['type','break','lengths'],
    'ioconf.plain'      => ['type','perm','with_original'],
    'ioconf.ftp'        => ['type','perm','with_original'],
    'ioconf.db'         => ['type','perm','with_original']
};

internal 'default'     =>
#   Default values for configuration variables
{
    profile => 'csv',
    filters => '',
    ioconf  => 
    { 
        type    => 'plain', 
        perm    => 'r', 
        with_original => 0 
    },
    format =>
    {
        type    => 'delim'
    }
};


#   CONSTRUCTOR RELATED
sub init()
#   Rekindle all that we are
{
    my $self = shift;
    
    my $args = $self->reinit(@_);
    return $self;
}

sub reinit
{
    my $self = shift;
    my $args;

    return undef unless ($_[0]);
    
    #   Allow for hash or hashref args
    $args = (ref($_[0]) eq 'HASH') ? $_[0] : { @_ };
    
    populate($self, $args);
    
    $self->prep_collections();
    
    return $args;
}


sub prep_collections()
#   Prepare and store an instance of Data::All::IO::* for from and to configs 
{
    my $self = shift;
    
    foreach (qw(to from))
    {
        $self->__collection()->{$_} = $self->_load_IO($self->$_())
            if (defined($self->$_()));
    }
}


sub count(;$)
#   get a record count
{
    my $self = shift;
    my $which = shift || 'from';
    
    $self->open() unless ($self->is_open($which));
    return $self->__collection()->{$which}->count();
}


sub count_to(;$)
#   get a record count for the from config
{
    my $self = shift;
    return $self->count('to');
}


sub count_from(;$)
#   get a record count for the from config
{
    my $self = shift;
    return $self->count('from');
}

sub getrecord(;$$)
#   Get a single, consecutive record
{
    my $self = shift;
    my $type = shift || 'hash';
    my $meth = 'getrecord_' . $type;
    my $record;
    
#    $record = ($self->__collection()->{'from'}->can($meth))
#        ? $self->__collection()->{'from'}->$meth()
#        : undef;

    return $self->__collection()->{'from'}->getrecord_hash();
}

sub putrecord()
#   Put a single, consecutive record
{
    my $self = shift;
    my $record = shift || return undef;
    
    $self->__collection()->{'to'}->putrecord()
}


sub collection(%)
#   Shorthand for creating a Data::All instance, openning, reading
#   and closing the data source
{
    my ($conf1, $conf2) = @_;
    my ($myself, $rec);
    
    #   We can accept standard-arg style, but we will also make provisions
    #   for a single hashref arg which we'll assume is the 'from' config
    $myself = (ref($_[0]) ne 'HASH')
        ? new('Data::All', @_)
        : new('Data::All', from => $_[0]);
        
    $myself->open();
    $rec = $myself->read();
    $myself->close();
    
    return (!wantarray) ? $rec : @{ $rec };
}

sub open(;$)
{
    my $self = shift;
    #my $which = shift || 'from';
    
    foreach my $source (keys %{ $self->__collection() })
    {
        $self->__collection()->{$source}->open();
        
        unless ($self->__collection()->{$source}->is_open())
        {
            $self->__ERROR($self->__collection()->{$source}->__ERROR());
            die "Cannot open ", $self->__collection()->{$source}->create_path();
        }
    }
    
    return;
}

sub close(;$)
{
    my $self = shift;
    #my $which = shift || 'from';
    
    foreach my $source (keys %{ $self->__collection() })
    {
        $self->__collection()->{$source}->close();
    }
    
    return;
}

sub show_fields(;$)
{
    my $self = shift;
    my $which = shift || 'from';
    $self->__collection()->{$which}->fields();
}

sub read(;$$)
{
    my $self = shift; 
    my $which = shift || 'from';
    
    $self->open();
    my $records = $self->__collection()->{$which}->getrecords();
    
    return !wantarray ? $records :   @{ $records };
}

sub store
#   Store data from an array ref (of hashes) into a Data::All enabled source
#    IN: (arrayref) of hashes -- your records
#         [ standard parameters ]
#   OUT: 
{
    my $self = shift;
    my $from = shift;
    my ($to, $bool);
    
    my $args = $self->reinit(@_);
    
    $to = $self->__collection()->{'to'};
    
    $to->open();
    
    $to->fields([keys %{ $from->[0] }])
        unless ($to->fields() && $#{ $to->fields() });
        
    $to->putfields()   if ($self->print_fields);

    #   Convert data in a wholesome fashion (rather than piecemeal)
    #   There is no point in doing it record by record b/c the 
    #   records we are storing are already in memory.
    $bool = $to->putrecords($from, $args) ;
    
    $to->close();
    
    return 1;
}

sub convert
#   Move data from one Data::All collection to another, using a simple 
#   from (source) and to (target) metaphor
#   TODO: need error detection
{
    my $self = shift;
    my ($from, $to, $bool);
    
    my $args = $self->reinit(@_);

    ($from, $to) = @{ $self->__collection() }{'from','to'};

    $from->open();
    $to->open();
    
    # TODO: Get fields from db SELECT before we copy to the $to->fields()
    
    #   Use the from's field names if the to's has none
    $to->fields($from->fields) unless ($to->fields() && $#{ $to->fields() });
 
    #   Print the field names into the to
    #   TODO: If the field list is in the from collection, then the
    #   fields will appear twice in the to file. 
    $to->putfields()   if ($self->print_fields);
    
    if ($self->atomic) {
        #   Convert data in a wholesome fashion (rather than piecemeal)
        $bool = $to->putrecords([$from->getrecords()], $args) ;
    }
    else {
    #   Convert record by record (great for large family members!!!!!!!)
        while (my $rec = $from->getrecord_hash()) 
        { $bool = $to->putrecord($rec, $args) }
    }
    
    #   BUG: I commented this out for the extract specifically (delano - May 9) 
    #$to->close();
    #$from->close();
    
    return $bool;
}


sub write(;$$)
{
    my $self = shift;
    my $which = shift || 'from';
    my ($start, $count) = (shift || 0, shift || 0); 
        
}


sub is_open(;$)
{ 
    my $self = shift;
    my $which = shift || 'from';
    
    return $self->__collection()->{'from'}->is_open();
}





sub _load_IO(\%)
#   Load an instance of Data::All::IO::? to memory
{
    my $self = shift;
    my $args = shift;
    $self->_parse_args($args);
    my ($ioconf, $format, $path, $fields) = @{ $args }{'ioconf','format','path','fields'};
    
    my $IO = Data::All::IO->new($ioconf->{'type'}, 
        { 
            ioconf  => $ioconf, 
            format  => $format, 
            path    => $path, 
            fields  => $fields
        });
        
    return $IO;
}

sub _parse_args()
#   Convert arrayref args into hashref, process determinable values, 
#   and apply defaults to the rest. We can also through a horrible
#   error at this point if there isn't enoguh info for Data::All to
#   continue.
{
    my $self = shift;
    my $args = shift;
   
    #   TODO: Allow collection('filename.csv', 'profile'); usage
    $self->_apply_profile_to_args($args);
    
    #   Make sure path is an array ref
    $args->{'path'} = [$args->{'path'}]  if (ref($args->{'path'}) ne 'ARRAY');
    
    for my $a (keys %{ $self->__default() })
    #   Apply default values to data collection configuration. Amplify arrayref 
    #   configs into hashref configs using the a2h_templates where appropriate.
    { 
        next if $a eq 'path';
        
        if (ref($args->{$a}) eq 'ARRAY')
        {
            my (%hash, $templ);
            $templ = join '', $a, '.', $args->{$a}->[0];
            @hash{@{$self->__a2h_template()->{$templ}}} = @{ $args->{$a} };
                        
            $args->{$a} = \%hash;
        }
        
        $self->_apply_default_to($a, $args);
    }
    
    return if ($args->{'moniker'});
    
    $args->{'moniker'} = ($args->{'ioconf'}->{'type'} ne 'db')
        ? join('', @{ $args->{'path'} })
        : '_';
    
}

sub _apply_profile_to_args(\%)
#   Populate format within args based on a preconfigured profile
{
    my $self = shift;
    my $args = shift;
    my $p = $args->{'profile'} || $self->__default()->{'profile'};
    
    return if (exists($args->{'format'}));
    
    die("There is no profile for type $p ") 
        unless ($p && exists($self->__profile()->{$p}));
        
    #   Set the format using the requested profile
    $args->{'format'} = $self->__profile()->{$p};
    return;
}

sub _apply_default_to()
#   Set a default value to a particular attribute.
#   TODO: Allow setting of individual attribute fields
{
    my $self = shift;
    my ($a, $args) = @_;
    $args->{$a} = $self->__default()->{$a}
        unless (exists($args->{$a}));
    
    return unless (ref($args->{$a}) eq 'HASH');
    
    foreach my $c (keys %{ $self->__default()->{$a} })
    {
        $args->{$a}->{$c} = $self->__default()->{$a}->{$c}
            unless (defined($args->{$a}->{$c}));
    }

}


BEGIN {
    Data::All::IO->register_factory_type( plain => 'Data::All::IO::Plain');
    Data::All::IO->register_factory_type(   xml => 'Data::All::IO::XML');
    Data::All::IO->register_factory_type(    db => 'Data::All::IO::Database');
    Data::All::IO->register_factory_type(   ftp => 'Data::All::IO::FTP');
    
    #Data::All::Format->register_factory_type( delim => 'Data::All::Format::Delim');
    #Data::All::Format->register_factory_type( fixed => 'Data::All::Format::Fixed');
    #Data::All::Format->register_factory_type(  hash => 'Data::All::Format::Hash');
}



#   $Log: All.pm,v $
#   Revision 1.1.1.1  2005/05/10 23:56:20  dgrant
#   initial import
#
#   Revision 1.1.1.1.8.36  2004/09/07 00:43:08  dgrant
#   - Changed print_fields to default to 0
#
#   Revision 1.1.1.1.8.35  2004/08/18 18:13:01  dgrant
#   - Tweaked getrecord(), removed if () test to see if the collection can get a
#   record of the requested type. It is either going to be a hashref (hardcoded) or
#   an arrayref (possible, but not currently reflected)
#
#   Revision 1.1.1.1.8.34  2004/08/12 18:40:45  dgrant
#   *** empty log message ***
#
#   Revision 1.1.1.1.8.30  2004/05/26 07:28:02  dgrant
#   *** empty log message ***
#
#   Revision 1.1.1.1.8.29  2004/05/20 17:45:08  dgrant
#   - Added Data::All::store()
#   - Some bug fixes
#
#   Revision 1.1.1.1.8.28  2004/05/20 17:43:40  dgrant
#   *** empty log message ***
#
#   Revision 1.1.1.1.8.27  2004/05/18 00:43:03  dgrant
#   - Misc bug fixes
#
#   Revision 1.1.1.1.8.26  2004/05/17 22:34:09  dgrant
#   - Overhauled the interface to Data::All.
#   	- the standard fields are now from =>, to =>, ... which can be
#   overridden on an case by case basis (i.e. send to => ..., to new() and you
#   can send another to convert() to be used instead).
#   	- Removed the whole moniker thing. It was stupid and I never used
#   and I don't think anyone in their right mind ever would use it :-p
#   	- convert() no longer accepts arrayrefs of data to convert (instead
#   of using the "from" config). This functionality will appear as the method
#   store() shortly.
#   - Now at version 0.31
#
#
#   Revision 1.1.1.1.8.10  2004/04/29 22:03:21  dgrant
#   - Added count() functionality exposed through Data:All so we can get the
#   line count in files and the COUNT(*) for SELECT queries
#   - Fixed a database disconnection bug (caused queries to rollback)
#   - Statement handled are now finished too
#
#   Revision 1.1.1.1.8.4  2004/04/24 01:22:35  dgrant
#   - Added CPAN documentation to Data::All and updated the examples to be
#   distribution friendly
#
#   Revision 1.1.1.1.8.2  2004/04/16 19:01:16  dgrant
#   - Fixed Data::All::fields() bug (overlapped the attribute fields). Renamed 
#   to show_fields()
#
#   Revision 1.1.1.1.8.1  2004/04/16 17:10:32  dgrant
#   - Merging libperl-016 changes into the libperl-1-current trunk
#   - Changed Format::Delim to use Text::Parsewords (again). There
#     is a bug in Text::Parsewords that causes it to bawk when a
#     ' (single quote) character is present in the string (BOO!).
#     I wrote a temp work around (replace it with \'), but we will
#     need to do something about that.
#
#   Revision 1.1.1.1.2.6  2004/03/25 02:06:54  dgrant
#   - Added use perl 5.6
#   - In the midst of changes mainly for upgrading the delimited functionality
#   - pre-011 version commit
#   - Database currently not working, but delim to delim is
#   - convert() works
#   - See examples/1 for working example
#
#   Revision 1.1.1.1.2.5  2004/03/25 01:47:09  dgrant
#   - Initial import of modules
#   - Included CVS Id and Log variables
#   - Added use strict; to a few unlucky modules


1;
__END__


=head1 NAME

Data::All - Access to data in many formats from many places

=head1 WARNING!
I have added versions of IO::All and Spiffy to the Data:All 
distribution b/c it requires these specific versions and 
the Data::All rewrite that doesn't use IO:All is incomplete. 
This could overwrite newer versions of these modules you
currently have installed. If you still want to use Data::All
I recommend installing it to a non-standard location such
as under your project/lib directory using something like:

$ perl Makefile.PL PREFIX=/path/to/install


=head1 SYNOPSIS 1 (short)

    use Data::All;
    
    #   Create an instance of Data::All for database data
    my $input = Data::All->new(
        from => { path => '/some/file.csv', profile => 'csv' },
        to   => { path => '/tmp/file.tab',  profile => 'tab'}
    );
    
    #   $rec now contains an arrayref of hashrefs for the data defined in %db.
    #   collection() is a shortcut (see Synopsis 2)
    my $rec  = $input1->read();

    #   Convert "from" to "to"
    $input->convert(); 

    #   $rec is the same above   
    #   NOTE: The hash reference here is different than the hash used by new()
    my $rec = collection({'path' => '/some/file.csv', profile => 'csv'});
    
=head1 SYNOPSIS 2 (long)

    use Data::All;
    
    my $dsn1     = 'DBI:mysql:database=mysql;host=YOURHOST;';
    my $dsn2     = 'DBI:Pg:database=SOMEOTHERDB;host=YOURHOST;';
    my $query1   = 'SELECT `Host`, `User`, `Password` FROM user';
    my $query2   = 'INSERT INTO users (`Password`, `User`, `Host`) VALUES(?,?,?)';
    
    my %db1 = 
    (   path        => [$dsn1, 'user', 'pass', $query1],
        ioconf      => ['db', 'r' ]
    );
    
    #   Notice how the parameters can be sent as a well-ordered arrayref
    #   or as an explicit hashref. 
    my %db2 = 
    (   path        => [$dsn2, 'user', 'pass', $query2],
        ioconf      => { type => 'db', perms => 'w' },
        fields      => ['Password', 'User', 'Host']
    );
    
    #   This is an explicit csv format. This is the same as using 
    #   profile => 'csv'. NOTE: the 'w' is significant as it is passed to 
    #   IO::All so it knows how to properly open and lock the file. 
    my %file1 = 
    (
        path        => ['/tmp/', 'users.csv'],
        ioconf      => ['plain', 'rw'],
        format      => {
            type    => 'delim', 
            breack  => "\n", 
            delim   => ',', 
            quote   => '"', 
            escape  => '\\',
        }
    );
    
    #   The only significantly different here is with_original => 1.
    #   This tells Data::All to include the original record as a field 
    #   value. The field name is _ORIGINAL. This is useful for processing
    #   data when auditing the original source is required.         
    my %file2 = 
    (
        path        => '/tmp/users.fixed',
        ioconf      => {type=> 'plain', perms => 'w', with_original => 1],
        format      => { 
            type    => 'fixed', 
            break   => "\n", 
            lengths => [32,16,64]
        },
        fields      => ['pass','user','host']
    );
    
    #   Create an instance of Data::All for database data.
    #   Note: parameters can also be a hash or hashref
    my $input1 = Data::All->new({
        from => %db1, 
        to => \%db2,
        print_fields => 0,              #   Do not output field name record
        atomic => 1                     #   Load the input completely before outputting
    });
    
    $input1->convert();                 #   Save the mysql data to the postgresql table 
    $input1->convert(to => \%file1);    #   And also save it to a CSV format
    $input1->convert(to => \%file2);    #   And also save it to a fixed format
    
    #   Read the fixed file we just created into an arrayref of hashes
    my $records = collection(from => \%file2);    
    
=head1 DESCRIPTION

Data::All is based on a few abstracted concepts. The line is a record and a 
group of records is a collection. This allows a common record storing concept
to be used across any number of data sources (delimited file, XML over a socket,
a database table, etc...). 

Supported formats: delimited and fixed (for filesystem types)
Supported sources: local filesystem, database, socket (not heavily tested).

Similar to AnyData, but more suited towards converting data types 
from and to various sources rather than reading data and playing with it. It is
like an extension to IO::All which gives you access to data sources; Data::All
gives you access to data. 

Conversion now happens record by record by default. You can set this explicitly
by sending atomic => 1 or 0 [default] through to new() or convert(). 

Data::All is a Spiffy module so you should be able to subclass Data::All or any
of the Data::All::* classes to suite your own needs. It was written with Spiffy 
0.15 but should work with later versions (depending on Spiffy's version to 
version compatibility!).

=head1 TODO LIST

Current major development areas are the interface and format 
stability. Upcoming development are breadth of features (more formats, more
sources, ease of use, reliable subclassing, documentation/tests, and speed).

Misc:
TODO:Allow a buffer to give some flexibility between record by record and atomic processing.
TODO:Add ability to create temporary files
TODO:Allow handling record fields with arrayrefs for anon / non-hash access
TODO:Default values for fields (avoid undef db errors)
TODO:Allow modifying data in memory and saving it back to a file
TODO:Consider using a standard internal structure, so every source is converted into this structure (hash, Stone?)
TODO:Add SQL as a readable input and output
TODO:Expose format functions to Data::All users so simple single record conversion can be thoroughly utilized.

=head1 STABILITY

This module is currently undergoing rapid development and there is much left to 
do. It is still in the alpha stage, so it is definitely not recommended for
production use. In particular the interface(s) have changed and may change 
again. I have personally been tested it on Solaris 8 (SPARC64) and FreeBSD 4.9 
(i386). Because of the way Data::All::IO::Plain and Data::All::IO::FTP treat
filepaths, Data::All will have problems on non-*nix platforms. I will eventually
get around to making Data::All platform independant, but other features take
priority. You're welcome to write a patch and send it to me though :]

=head1 KNOWN BUGS

- The record separator does not currently work properly as it is hardcoded 
to be newline (for delimited and fixed formats). 
- The examples/* aren't always 100% in sync with the latest changes to Data::All.
- If the first column is empty, it may screw up Data::All::Format::Delim (it
will return undef for that column and the remaining columns with shift left)

=head1 SEE ALSO

IO::All, AnyData, Spiffy

=head1 AUTHOR

Delano Mandelbaum, E<lt>horrible<AT>murderer.caE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004 by Delano Mandelbaum

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.3 or,
at your option, any later version of Perl 5 you may have available.


=cut
