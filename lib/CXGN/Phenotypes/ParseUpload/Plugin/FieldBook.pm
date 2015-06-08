
package CXGN::Phenotypes::ParseUpload::Plugin::FieldBook;

use Moose;
use File::Slurp;

sub name {
    return "field book";
}

sub validate {
    my $self = shift;
    my $filename = shift;
    my @file_lines;
    my $delimiter = ',';
    my $header;
    my @header_row;

    ## Check that the file could be read
    @file_lines = read_file($filename);
    if (!@file_lines) {
	print STDERR "Could not read file\n";
	return;
    }
    ## Check that the file has at least 2 lines;
    if (scalar(@file_lines < 2)) {
	print STDERR "File has less than 2 lines\n";
	return;
    }

    $header = shift(@file_lines);
    chomp($header);
    @header_row = split($delimiter, $header);

    #  Check header row contents
    if ($header_row[0] ne "\"plot_id\"" ||
	$header_row[-1] ne "\"location\"" ||
	$header_row[-2] ne "\"timestamp\"" ||
	$header_row[-3] ne "\"person\"" ||
	$header_row[-4] ne "\"value\"" ||
	$header_row[-5] ne "\"trait\""
       ) {
	print STDERR "File contents incorrect\n";
	return;
    }

    return 1;
}

sub parse {
    my $self = shift;
    my $filename = shift;
    my %parse_result;
    my @file_lines;
    my $delimiter = ',';
    my $header;
    my @header_row;
    my $header_column_number = 0;
    my %header_column_info; #column numbers of key info indexed from 0;
    my %plots_seen;
    my %traits_seen;
    my @plots;
    my @traits;
    my %data;

    #validate first
    if (!$self->validate($filename)) {
	$parse_result{'error'} = "File not valid";
	print STDERR "File not valid\n";
	return \%parse_result;
    }

    @file_lines = read_file($filename);
    $header = shift(@file_lines);
    chomp($header);
    @header_row = split($delimiter, $header);

    ## Get column numbers (indexed from 1) of the plot_id, trait, and value.
    foreach my $header_cell (@header_row) {
	$header_cell =~ s/\"//g; #substr($header_cell,1,-1);  #remove double quotes
	if ($header_cell eq "plot_id") {
	    $header_column_info{'plot_id'} = $header_column_number;
	}
	if ($header_cell eq "trait") {
	    $header_column_info{'trait'} = $header_column_number;
	}
	if ($header_cell eq "value") {
	    $header_column_info{'value'} = $header_column_number;
	}
	$header_column_number++;
    }
    if (!defined($header_column_info{'plot_id'}) || !defined($header_column_info{'trait'}) || !defined($header_column_info{'value'})) {
	$parse_result{'error'} = "plot_id and/or trait columns not found";
	print STDERR "plot_id and/or trait columns not found";
	return \%parse_result;
    }

    foreach my $line (@file_lines) {
	chomp($line);
     	my @row =  split($delimiter, $line);
	my $plot_id = $row[$header_column_info{plot_id}];
	$plot_id =~ s/\"//g;
#substr($row[$header_column_info{'plot_id'}],1,-1);
	my $trait = $row[$header_column_info{'trait'}];
	$trait =~ s/\"//g;
#substr($row[$header_column_info{'trait'}],1,-1);
	my $value = $row[$header_column_info{'value'}];
	$value =~ s/\"//g;
#substr($row[$header_column_info{'value'}],1,-1);
	if (!defined($plot_id) || !defined($trait) || !defined($value)) {
	    $parse_result{'error'} = "error getting value from file";
	    print STDERR "value: $value\n";
	    return \%parse_result;
	}
	$plots_seen{$plot_id} = 1;
	$traits_seen{$trait} = 1;
	$data{$plot_id}->{$trait} = $value;
    }

    foreach my $plot (keys %plots_seen) {
	push @plots, $plot;
    }
    foreach my $trait (keys %traits_seen) {
	push @traits, $trait;
    }

    $parse_result{'data'} = \%data;
    $parse_result{'plots'} = \@plots;
    $parse_result{'traits'} = \@traits;

    return \%parse_result;
}

1;
