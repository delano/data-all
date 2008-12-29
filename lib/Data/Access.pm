package Data::Access;

use strict;

                                         
use Params::Flex;
use Class::MakeMethods::Template::Hash;

#  -------------------------------------------  INTERFACE  -----
sub close;
sub convert;
sub count;
sub define;
sub open;


sub define {
    my $proto = {
        
    };
    my $args = Params::Flex::flex(@_, $proto);
}


#  ----------------------------------------------  IMPORT  -----
sub import {
    my $class = shift;
    
    $class->_import_version( shift )
        if ( scalar @_ and $_[0] =~ m/^\d/ );

    $class->flex( @_ ) if ( scalar @_ );
}
sub _import_version {
    my $class = shift;
    my $wanted = shift;
    
    no strict;
    my $version = ${ $class.'::VERSION '} || 0;
    
    # If passed a version number, ensure that we measure up.
    # Based on similar functionality in Class::MakeMethods
    die "$class requested v$wanted, but I'm $version\n"
        if ( ! $version or $version < $wanted );
}

1;