use Test::Most tests => 3;

use Modern::Perl;
use File::Copy;
use CXGN::BlastDB;
use File::Spec::Functions;

use lib 't/lib';
use SGN::Test::WWW::Mechanize skip_cgi => 1;

my $urlbase = "/tools/blast/view_result.pl";
my $mech    = SGN::Test::WWW::Mechanize->new;
my $report  = catfile(qw/t data blastreport/);

$mech->with_test_level( local => sub {
    my $c = $mech->context;
    my $temp_base = $c->config->{tempfiles_base} ||
        "/tmp/" . $c->config->{www_user} . "/SGN-site";
    my $blast_dir = catdir($temp_base, 'blast');

    unless (-e $blast_dir) {
        diag "Creating $blast_dir";
        mkdir $blast_dir;
    }

    diag "Copying $report to $blast_dir";
    copy($report, $blast_dir);

    my $url = "$urlbase?output_graphs=bioperl_histogram&filterq=1&file=&maxhits=100&matrix=BLOSUM62&program=blastn&database=3&interface_type=simple&outformat=0&expect=1e-10&seq_count=1&report_file=blastreport";
    $mech->get_ok($url);
    $mech->content_like(qr/BLAST Results/);
    $mech->content_unlike(qr/No hits found/);

    for my $f (glob("$blast_dir/*")) {
        diag "Removing $f";
        unlink $f;
    }
    diag "Removing $blast_dir";
    unlink $blast_dir;
});
