
#	A simple, file-based test for Data::All
#       may-6-2004, delano mandelbaum

#########################

use Test::More;
BEGIN { plan tests => 4 };
use Data::All;
ok(1, "Module loaded"); 

#########################

use FindBin;

my %infile = (
	path	=> $FindBin::Bin . '/sample.csv',
	profile => 'csv',
	ioconf  => ['plain', 'r']
);

my %outfile = (
        path    => $FindBin::Bin . '/sample.fixed',
        format	=> ['fixed', "\n", [16,4,32,32]],
        ioconf  => ['plain', 'w']
);

my $da = Data::All->new(from =>\%infile, to=> \%outfile);

$da->open();

my $rec = $da->read();

ok($#{ $rec } == 2, "Check record count");
ok(exists($rec->[0]->{'name'}), "Check field names");

$da->convert();

ok(1);
