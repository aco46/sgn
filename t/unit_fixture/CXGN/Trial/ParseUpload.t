
use strict;
use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;
use CXGN::Trial::ParseUpload;

my $f = SGN::Test::Fixture->new();

my $p = CXGN::Trial::ParseUpload->new( { filename => "t/data/genotype_trial_upload/CASSAVA_GS_74Template", chado_schema=> $f->bcs_schema() });
$p->load_plugin("ParseIGDFile");

my $results = $p->parse();
my $errors = $p->get_parse_errors();

ok(scalar(@$errors) == 0, "no parse errors");

is_deeply( $results, { trial_name => "CASSAVA_GS_74", blank_well => "F05", user_id=>'I.Rabbi@cgiar.org', project_name => 'NEXTGENCASSAVA' }, "parse results test");

print STDERR join ",", @{$p->get_parse_errors()};

$p = CXGN::Trial::ParseUpload->new( { filename => "t/data/genotype_trial_upload/CASSAVA_GS_74Template_missing_blank", chado_schema=> $f->bcs_schema() });
$p->load_plugin("ParseIGDFile");

$results = $p->parse();
$errors = $p->get_parse_errors();

ok($errors->[0] eq "No blank well found in spreadsheet", "detect missing blank entry");

$p = CXGN::Trial::ParseUpload->new( { filename => "t/data/genotype_trial_upload/CASSAVA_GS_74Template_messed_up_trial_name", chado_schema=> $f->bcs_schema() });
$p->load_plugin("ParseIGDFile");

$results = $p->parse();
$errors = $p->get_parse_errors();

ok($errors->[0] eq "All trial names in the trial column must be identical", "detect messed up trial name");



done_testing();
