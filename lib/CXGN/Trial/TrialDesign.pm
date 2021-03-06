package CXGN::Trial::TrialDesign;

=head1 NAME

CXGN::Trial::TrialDesign - a module to create a trial design using the R CRAN package Agricolae.


=head1 USAGE

 my $trial_design = CXGN::Trial::TrialDesign->new({schema => $schema} );


=head1 DESCRIPTION

This module uses the the R CRAN package "Agricolae" to calculate experimental designs for field layouts.

=head1 AUTHORS

 Jeremy D. Edwards (jde22@cornell.edu)
 Aimin Yan (ay247@cornell.edu)
=cut

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Data::Dumper;
use R::YapRI::Base;
use R::YapRI::Data::Matrix;
use POSIX;

has 'trial_name' => (isa => 'Str', is => 'rw', predicate => 'has_trial_name', clearer => 'clear_trial_name');
has 'stock_list' => (isa => 'ArrayRef[Str]', is => 'rw', predicate => 'has_stock_list', clearer => 'clear_stock_list');
has 'control_list' => (isa => 'ArrayRef[Str]', is => 'rw', predicate => 'has_control_list', clearer => 'clear_control_list');
has 'number_of_blocks' => (isa => 'Int', is => 'rw', predicate => 'has_number_of_blocks', clearer => 'clear_number_of_blocks');
has 'block_row_numbers' => (isa => 'Int', is => 'rw', predicate => 'has_block_row_numbers', clearer => 'clear_block_row_numbers');
has 'block_col_numbers' => (isa => 'Int', is => 'rw', predicate => 'has_block_col_numbers', clearer => 'clear_block_col_numbers');
has 'number_of_rows' => (isa => 'Int',is => 'rw',predicate => 'has_number_of_rows',clearer => 'clear_number_of_rows');
has 'number_of_cols' => (isa => 'Int',is => 'rw',predicate => 'has_number_of_cols',clearer => 'clear_number_of_cols');
has 'number_of_reps' => (isa => 'Int', is => 'rw', predicate => 'has_number_of_reps', clearer => 'clear_number_of_reps');
has 'block_size' => (isa => 'Int', is => 'rw', predicate => 'has_block_size', clearer => 'clear_block_size');
has 'maximum_block_size' => (isa => 'Int', is => 'rw', predicate => 'has_maximum_block_size', clearer => 'clear_maximum_block_size');
has 'plot_name_prefix' => (isa => 'Str', is => 'rw', predicate => 'has_plot_name_prefix', clearer => 'clear_plot_name_prefix');
has 'plot_name_suffix' => (isa => 'Str', is => 'rw', predicate => 'has_plot_name_suffix', clearer => 'clear_plot_name_suffix');
has 'plot_start_number' => (isa => 'Int', is => 'rw', predicate => 'has_plot_start_number', clearer => 'clear_plot_start_number', default => 1);
has 'plot_number_increment' => (isa => 'Int', is => 'rw', predicate => 'has_plot_number_increment', clearer => 'clear_plot_number_increment', default => 1);
has 'randomization_seed' => (isa => 'Int', is => 'rw', predicate => 'has_randomization_seed', clearer => 'clear_randomization_seed');
has 'blank' => ( isa => 'Str', is => 'rw', predicate=> 'has_blank' );

subtype 'RandomizationMethodType',
  as 'Str',
  where { $_ eq "Wichmann-Hill" || $_ eq  "Marsaglia-Multicarry" || $_ eq  "Super-Duper" || $_ eq  "Mersenne-Twister" || $_ eq  "Knuth-
TAOCP" || $_ eq  "Knuth-TAOCP-2002"},
  message { "The string, $_, was not a valid randomization method"};

has 'randomization_method' => (isa => 'RandomizationMethodType', is => 'rw', default=> "Mersenne-Twister");

subtype 'DesignType',
  as 'Str',
  where { $_ eq "CRD" || $_ eq "RCBD" || $_ eq "Alpha" || $_ eq "Augmented" || $_ eq "MAD" || $_ eq "genotyping_plate" },
  message { "The string, $_, was not a valid design type" };

has 'design_type' => (isa => 'DesignType', is => 'rw', predicate => 'has_design_type', clearer => 'clear_design_type');

my $design;

sub get_design {
  return $design;
}

sub calculate_design {
  my $self = shift;
  if (!$self->has_design_type()) {
    return;
  }
  else {
    if ($self->get_design_type() eq "CRD") {
      $design = _get_crd_design($self);
    }
    elsif ($self->get_design_type() eq "RCBD") {
      $design = _get_rcbd_design($self);
    }
    elsif ($self->get_design_type() eq "Alpha") {
      $design = _get_alpha_lattice_design($self);
    }
    elsif ($self->get_design_type() eq "Augmented") {
       $design = _get_augmented_design($self);
    #  $design = _get_alpha_lattice_design($self);
    }

#    elsif ($self->get_design_type() eq "MADII") {
#      $design = _get_madii_design($self);
#    }

    elsif($self->get_design_type() eq "MAD") {
	$design = _get_madiii_design($self);
    }
    elsif ($self->get_design_type() eq "genotyping_plate") { 
	$design = $self->_get_genotyping_plate();
    }
#    elsif($self->get_design_type() eq "MADIV") {
#        $design = _get_madiv_design($self);
#    }

    else {
      die "Trial design" . $self->get_design_type() ." not supported\n";
    }
  }
  if ($design) {
    return 1;
  } else {
    return 0;
  }
}

sub _get_genotyping_plate { 
    my $self = shift;
    my %gt_design;
    my @stock_list;
    my $number_of_stocks;
    if ($self->has_stock_list()) { 
	@stock_list = @{$self->get_stock_list()};
	$number_of_stocks = scalar(@stock_list);
	if ($number_of_stocks > 95) { 
	    die "Need fewer than 96 stocks per plate (at least one blank!)";
	}
    }
    else { 
	die "No stock list specified\n";
    }
    
    my $blank = "";
    if ($self->has_blank()) { 
	$blank = $self->get_blank();
	print STDERR "Using previously set blank $blank\n";
    }
    else { 
	my $well_no = int(rand() * $number_of_stocks)+1;
	my $well_row = chr(int(($well_no-1) / 12) + 65);
	my $well_col = ($well_no -1) % 12 +1;
	$blank = sprintf "%s%02d", $well_row, $well_col;
	print STDERR "Using randomly assigned blank $blank\n";
    }
    
    my $count = 0;

    foreach my $row ("A".."H") {
	foreach my $col (1..12) {
	    $count++;
	    my $well= sprintf "%s%02d", $row, $col;
	    #my $well = $row.$col;
	    
	    if ($well eq $blank) { 
		$gt_design{$well} = { 
		    plot_name => $self->get_trial_name()."_".$well."_BLANK",
		    stock_name => "BLANK",
		};
	    }
	    elsif (@stock_list) { 
		$gt_design{$well} = 
		{ plot_name => $self->get_trial_name()."_".$well, 
		  stock_name => shift(@stock_list),
		};
	    }
	    #print STDERR Dumper(\%gt_design);
	}
    }
    return \%gt_design;
    
}

sub _get_crd_design {
  my $self = shift;
  my %crd_design;
  #$self->set_number_of_blocks(1);
  #%crd_design=%{_get_rcbd_design($self)};
  my $rbase = R::YapRI::Base->new();
  my @stock_list;
  my $number_of_blocks;
  my $number_of_reps;
  my $stock_data_matrix;
  my $r_block;
  my $result_matrix;
  my @plot_numbers;
  my @stock_names;
  my @block_numbers;
  my @rep_numbers;
  my @converted_plot_numbers;
  my $number_of_stocks;
  if ($self->has_stock_list()) {
    @stock_list = @{$self->get_stock_list()};
    $number_of_stocks = scalar(@stock_list);
  } else {
    die "No stock list specified\n";
  }
  if ($self->has_number_of_reps()) {
    $number_of_reps = $self->get_number_of_reps();
  } else {
    die "Number of reps not specified\n";
  }
  $stock_data_matrix =  R::YapRI::Data::Matrix->new(
						       {
							name => 'stock_data_matrix',
							rown => 1,
							coln => scalar(@stock_list),
							data => \@stock_list,
						       }
						      );
  $r_block = $rbase->create_block('r_block');
  $stock_data_matrix->send_rbase($rbase, 'r_block');

  $r_block->add_command('library(agricolae)');
  $r_block->add_command('trt <- stock_data_matrix[1,]');
  $r_block->add_command('rep_vector <- rep('.$number_of_reps.',each='.$number_of_stocks.')');
  $r_block->add_command('randomization_method <- "'.$self->get_randomization_method().'"');

  if ($self->has_randomization_seed()){
    $r_block->add_command('randomization_seed <- '.$self->get_randomization_seed());
    $r_block->add_command('crd<-design.crd(trt,rep_vector,serie=1,kinds=randomization_method, seed=randomization_seed)');
  }
  else {
    $r_block->add_command('crd<-design.crd(trt,rep_vector,serie=1,kinds=randomization_method)');
  }
  $r_block->add_command('crd<-crd$book'); #added for agricolae 1.1-8 changes in output
  $r_block->add_command('crd<-as.matrix(crd)');
  $r_block->run_block();
  $result_matrix = R::YapRI::Data::Matrix->read_rbase( $rbase,'r_block','crd');
  @plot_numbers = $result_matrix->get_column("plots");
  @rep_numbers = $result_matrix->get_column("r");
  @stock_names = $result_matrix->get_column("trt");
  @converted_plot_numbers=@{_convert_plot_numbers($self,\@plot_numbers)};
  for (my $i = 0; $i < scalar(@converted_plot_numbers); $i++) {
    my %plot_info;
    $plot_info{'stock_name'} = $stock_names[$i];
    $plot_info{'block_number'} = 1;
    $plot_info{'rep_number'} = $rep_numbers[$i];
    $plot_info{'plot_name'} = $converted_plot_numbers[$i];
    $crd_design{$converted_plot_numbers[$i]} = \%plot_info;
  }
  %crd_design = %{_build_plot_names($self,\%crd_design)};
  return \%crd_design;
}

sub _get_rcbd_design {
  my $self = shift;
  my %rcbd_design;
  my $rbase = R::YapRI::Base->new();
  my @stock_list;
  my $number_of_blocks;
  my $stock_data_matrix;
  my $r_block;
  my $result_matrix;
  my @plot_numbers;
  my @stock_names;
  my @block_numbers;
  my @converted_plot_numbers;

  if ($self->has_stock_list()) {
    @stock_list = @{$self->get_stock_list()};
  } else {
    die "No stock list specified\n";
  }
  if ($self->has_number_of_blocks()) {
    $number_of_blocks = $self->get_number_of_blocks();
  } else {
    die "Number of blocks not specified\n";
  }

  $stock_data_matrix =  R::YapRI::Data::Matrix->new(
						       {
							name => 'stock_data_matrix',
							rown => 1,
							coln => scalar(@stock_list),
							data => \@stock_list,
						       }
						      );
  $r_block = $rbase->create_block('r_block');
  $stock_data_matrix->send_rbase($rbase, 'r_block');
  $r_block->add_command('library(agricolae)');
  $r_block->add_command('trt <- stock_data_matrix[1,]');
  $r_block->add_command('number_of_blocks <- '.$number_of_blocks);
  $r_block->add_command('randomization_method <- "'.$self->get_randomization_method().'"');
  if ($self->has_randomization_seed()){
    $r_block->add_command('randomization_seed <- '.$self->get_randomization_seed());
    $r_block->add_command('rcbd<-design.rcbd(trt,number_of_blocks,serie=1,kinds=randomization_method, seed=randomization_seed)');
  }
  else {
    $r_block->add_command('rcbd<-design.rcbd(trt,number_of_blocks,serie=1,kinds=randomization_method)');
  }
  $r_block->add_command('rcbd<-rcbd$book'); #added for agricolae 1.1-8 changes in output
  $r_block->add_command('rcbd<-as.matrix(rcbd)');
  $r_block->run_block();
  $result_matrix = R::YapRI::Data::Matrix->read_rbase( $rbase,'r_block','rcbd');
  @plot_numbers = $result_matrix->get_column("plots");
  @block_numbers = $result_matrix->get_column("block");
  @stock_names = $result_matrix->get_column("trt");
  @converted_plot_numbers=@{_convert_plot_numbers($self,\@plot_numbers)};
  for (my $i = 0; $i < scalar(@converted_plot_numbers); $i++) {
    my %plot_info;
    $plot_info{'stock_name'} = $stock_names[$i];
    $plot_info{'block_number'} = $block_numbers[$i];
    $plot_info{'plot_name'} = $converted_plot_numbers[$i];
    $rcbd_design{$converted_plot_numbers[$i]} = \%plot_info;
  }
  %rcbd_design = %{_build_plot_names($self,\%rcbd_design)};
  return \%rcbd_design;
}

sub _get_alpha_lattice_design {
  my $self = shift;
  my %alpha_design;
  my $rbase = R::YapRI::Base->new();
  my @stock_list;
  my $block_size;
  my $number_of_blocks;
  my $number_of_reps;
  my $stock_data_matrix;
  my $r_block;
  my $result_matrix;
  my @plot_numbers;
  my @stock_names;
  my @block_numbers;
  my @rep_numbers;
  my @converted_plot_numbers;
  if ($self->has_stock_list()) {
    @stock_list = @{$self->get_stock_list()};
  } else {
    die "No stock list specified\n";
  }
  if ($self->has_block_size()) {
    $block_size = $self->get_block_size();
    print STDERR "block size = $block_size\n";
    if ($block_size < 3) {
      die "Block size must be greater than 2 for alpha lattice design\n";
    }
    #	print "stock_list: ".scalar(@stock_list)."block_size: $block_size\n";
    if (scalar(@stock_list) % $block_size != 0) {
      #die "Number of stocks (".scalar(@stock_list).") for alpha lattice design is not divisible by the block size ($block_size)\n";
	}
    else {
		my $dummy_var = scalar(@stock_list) % $block_size;		  
		my $stocks_to_add = $block_size - $dummy_var;
#		print "$stock_list\n";
		foreach my $stock_list_rep(1..$stocks_to_add) {
			push(@stock_list, $stock_list[0]);
		}
		$self->set_stock_list(\@stock_list);
	}
   
    $number_of_blocks = scalar(@stock_list)/$block_size;
    if ($number_of_blocks < $block_size) {
      die "The number of blocks ($number_of_blocks) for alpha lattice design must not be less than the block size ($block_size)\n";
    }
  } else {
    die "No block size specified\n";
  }
  if ($self->has_number_of_reps()) {
    $number_of_reps = $self->get_number_of_reps();
    if ($number_of_reps < 2) {
      die "Number of reps for alpha lattice design must be 2 or greater\n";
    }
  } else {
    die "Number of reps not specified\n";
  }
  $stock_data_matrix =  R::YapRI::Data::Matrix->new(
						       {
							name => 'stock_data_matrix',
							rown => 1,
							coln => scalar(@stock_list),
							data => \@stock_list,
						       }
						      );
  $r_block = $rbase->create_block('r_block');
  $stock_data_matrix->send_rbase($rbase, 'r_block');

  $r_block->add_command('library(agricolae)');
  $r_block->add_command('trt <- stock_data_matrix[1,]');
  $r_block->add_command('block_size <- '.$block_size);
  $r_block->add_command('number_of_reps <- '.$number_of_reps);
  $r_block->add_command('randomization_method <- "'.$self->get_randomization_method().'"');
  if ($self->has_randomization_seed()){
    $r_block->add_command('randomization_seed <- '.$self->get_randomization_seed());
    $r_block->add_command('alpha<-design.alpha(trt,block_size,number_of_reps,serie=1,kinds=randomization_method, seed=randomization_seed)');
  }
  else {
    $r_block->add_command('alpha<-design.alpha(trt,block_size,number_of_reps,serie=1,kinds=randomization_method)');
  }
  $r_block->add_command('alpha_book<-alpha$book');
  $r_block->add_command('alpha_book<-as.matrix(alpha_book)');

 my @commands = $r_block->read_commands();
    print STDERR join "\n", @commands;
    print STDERR "\n";


  $r_block->run_block();
 
  $result_matrix = R::YapRI::Data::Matrix->read_rbase( $rbase,'r_block','alpha_book');
  @plot_numbers = $result_matrix->get_column("plots");
  @block_numbers = $result_matrix->get_column("block");
  @rep_numbers = $result_matrix->get_column("replication");
  @stock_names = $result_matrix->get_column("trt");
  @converted_plot_numbers=@{_convert_plot_numbers($self,\@plot_numbers)};
  for (my $i = 0; $i < scalar(@converted_plot_numbers); $i++) {
    my %plot_info;
    $plot_info{'stock_name'} = $stock_names[$i];
    $plot_info{'block_number'} = $block_numbers[$i];
    $plot_info{'plot_name'} = $converted_plot_numbers[$i];
    $plot_info{'rep_number'} = $rep_numbers[$i];
    $alpha_design{$converted_plot_numbers[$i]} = \%plot_info;
  }
  %alpha_design = %{_build_plot_names($self,\%alpha_design)};
  return \%alpha_design;
}

sub _get_augmented_design {
  my $self = shift;
  my %augmented_design;
  my $rbase = R::YapRI::Base->new();
  my @stock_list;
  my @control_list;
  my $maximum_block_size;
  my $number_of_blocks;
  my $stock_data_matrix;
  my $control_stock_data_matrix;
  my $r_block;
  my $result_matrix;
  my @plot_numbers;
  my @stock_names;
  my @block_numbers;
  my @converted_plot_numbers;
  my %control_names_lookup;
  my $stock_name_iter;

  if ($self->has_stock_list()) {
    @stock_list = @{$self->get_stock_list()};
  } else {
    die "No stock list specified\n";
  }

  if ($self->has_control_list()) {
    @control_list = @{$self->get_control_list()};
    %control_names_lookup = map { $_ => 1 } @control_list;
    foreach $stock_name_iter (@stock_names) {
      if (exists($control_names_lookup{$stock_name_iter})) {
	die "Names in stock list cannot be used also as controls\n";
      }
    }
  } else {
    die "No list of control stocks specified.  Required for augmented design.\n";
  }

  if ($self->has_maximum_block_size()) {
    $maximum_block_size = $self->get_maximum_block_size();
    if ($maximum_block_size <= scalar(@control_list)) {
      die "Maximum block size must be greater the number of control stocks for augmented design\n";
    }
    if ($maximum_block_size >= scalar(@control_list)+scalar(@stock_list)) {
      die "Maximum block size must be less than the number of stocks plus the number of controls for augmented design\n";
    }
    $number_of_blocks = ceil(scalar(@stock_list)/($maximum_block_size-scalar(@control_list)));
  } else {
    die "No block size specified\n";
  }

  $stock_data_matrix =  R::YapRI::Data::Matrix->new(
						       {
							name => 'stock_data_matrix',
							rown => 1,
							coln => scalar(@stock_list),
							data => \@stock_list,
						       }
						      );

  $control_stock_data_matrix =  R::YapRI::Data::Matrix->new(
						       {
							name => 'control_stock_data_matrix',
							rown => 1,
							coln => scalar(@control_list),
							data => \@control_list,
						       }
						      );
  $r_block = $rbase->create_block('r_block');
  $stock_data_matrix->send_rbase($rbase, 'r_block');
  $control_stock_data_matrix->send_rbase($rbase, 'r_block');
  $r_block->add_command('library(agricolae)');
  $r_block->add_command('trt <- stock_data_matrix[1,]');
  $r_block->add_command('control_trt <- control_stock_data_matrix[1,]');
  $r_block->add_command('number_of_blocks <- '.$number_of_blocks);
  $r_block->add_command('randomization_method <- "'.$self->get_randomization_method().'"');
  if ($self->has_randomization_seed()){
    $r_block->add_command('randomization_seed <- '.$self->get_randomization_seed());
    $r_block->add_command('augmented<-design.dau(control_trt,trt,number_of_blocks,serie=1,kinds=randomization_method, seed=randomization_seed)');
  }
  else {
    $r_block->add_command('augmented<-design.dau(control_trt,trt,number_of_blocks,serie=1,kinds=randomization_method)');
  }
  $r_block->add_command('augmented<-augmented$book'); #added for agricolae 1.1-8 changes in output
  $r_block->add_command('augmented<-as.matrix(augmented)');

  $r_block->run_block();
  $result_matrix = R::YapRI::Data::Matrix->read_rbase( $rbase,'r_block','augmented');
  @plot_numbers = $result_matrix->get_column("plots");
  @block_numbers = $result_matrix->get_column("block");
  @stock_names = $result_matrix->get_column("trt");
  @converted_plot_numbers=@{_convert_plot_numbers($self,\@plot_numbers)};

  for (my $i = 0; $i < scalar(@converted_plot_numbers); $i++) {
    my %plot_info;
    $plot_info{'stock_name'} = $stock_names[$i];
    $plot_info{'block_number'} = $block_numbers[$i];
    $plot_info{'plot_name'} = $converted_plot_numbers[$i];
    $plot_info{'is_a_control'} = exists($control_names_lookup{$stock_names[$i]});
    $augmented_design{$converted_plot_numbers[$i]} = \%plot_info;
  }
  %augmented_design = %{_build_plot_names($self,\%augmented_design)};
  return \%augmented_design;

}

sub _get_madii_design {
    my $self = shift;
    my %madii_design;
 
    my $rbase = R::YapRI::Base->new();
  
    my @stock_list;
    my @control_list;
    my $maximum_block_size;
    my $number_of_blocks;
    my $number_of_rows;
    my $stock_data_matrix;
    my $control_stock_data_matrix;
    my $r_block;
    my $result_matrix;
    my @plot_numbers;
    my @stock_names;
    my @block_numbers;
    my @converted_plot_numbers;
    my %control_names_lookup;
    my $stock_name_iter;
    my @row_numbers;
    my @check_names;
    my @col_numbers;

    my $block_row_number;
    my $block_col_number;
    my @block_row_numbers;
    my @block_col_numbers;


  if ($self->has_stock_list()) {
    @stock_list = @{$self->get_stock_list()};
  } else {
    die "No stock list specified\n";
  }

  if ($self->has_control_list()) {
    @control_list = @{$self->get_control_list()};
    %control_names_lookup = map { $_ => 1 } @control_list;
    foreach $stock_name_iter (@stock_names) {
      if (exists($control_names_lookup{$stock_name_iter})) {
	die "Names in stock list cannot be used also as controls\n";
      }
    }
  } else {
    die "No list of control stocks specified.  Required for augmented design.\n";
  }

#    if ($self->has_number_of_blocks()) {
#    $number_of_blocks = $self->get_number_of_blocks();
#    } else {
#    die "Number of blocks not specified\n";
#    }

   if ($self->has_number_of_rows()) {
    $number_of_rows = $self->get_number_of_rows();
    } else {
    die "Number of rows not specified\n";
    }

    #system("R --slave --args $tempfile $tempfile_out < R/MADII_layout_function.R");
#     system("R --slave < R/MADII_layout_function.R");


#    if ($self->has_maximum_row_number()) {
#    $maximum_row_number = $self->get_maximum_row_number();
#    if ($maximum_block_size <= scalar(@control_list)) {
#      die "Maximum block size must be greater the number of control stocks for augmented design\n";
#    }
#    if ($maximum_block_size >= scalar(@control_list)+scalar(@stock_list)) {
#      die "Maximum block size must be less than the number of stocks plus the number of controls for augmented design\n";
#    }
#    $number_of_blocks = ceil(scalar(@stock_list)/($maximum_block_size-scalar(@control_list)));
#
#  } else {
#    die "No block size specified\n";
#  }


#  if ($self->has_maximum_block_size()) {
#    $maximum_block_size = $self->get_maximum_block_size();
#    if ($maximum_block_size <= scalar(@control_list)) {
#      die "Maximum block size must be greater the number of control stocks for augmented design\n";
#    }
#    if ($maximum_block_size >= scalar(@control_list)+scalar(@stock_list)) {
#      die "Maximum block size must be less than the number of stocks plus the number of controls for augmented design\n";
#    }
#    $number_of_blocks = ceil(scalar(@stock_list)/($maximum_block_size-scalar(@control_list)));
#  } else {
#    die "No block size specified\n";
#  }

#=comment

  print STDERR join "\n", "@stock_list\n";

  print STDERR join "\n", "$number_of_rows\n";

  $stock_data_matrix =  R::YapRI::Data::Matrix->new(
						       {
							name => 'stock_data_matrix',
							rown => 1,
							coln => scalar(@stock_list),
							data => \@stock_list,
						       }
						      );
  $control_stock_data_matrix =  R::YapRI::Data::Matrix->new(
						       {
							name => 'control_stock_data_matrix',
							rown => 1,
							coln => scalar(@control_list),
							data => \@control_list,
						       }
						      );


  $r_block = $rbase->create_block('r_block');
  $stock_data_matrix->send_rbase($rbase, 'r_block');
  $control_stock_data_matrix->send_rbase($rbase, 'r_block');

 #$r_block->add_command('library(agricolae)');

  $r_block->add_command('library(MAD)');


  $r_block->add_command('trt <- as.array(stock_data_matrix[1,])');
  $r_block->add_command('control_trt <- as.array(control_stock_data_matrix[1,])');


#  $r_block->add_command('trt <- stock_data_matrix[1,]');
#  $r_block->add_command('control_trt <- control_stock_data_matrix[1,]');



#  $r_block->add_command('acc<-c(seq(1,330,1))');
#  $r_block<-add_command('chk<-c(seq(1,4,1))');

#  $r_block->add_command('trt <- acc');
#  $r_block->add_command('control_trt <- chk');
#  $r_block->add_command('number_of_blocks <- '.$number_of_blocks);

   $r_block->add_command('number_of_rows <- '.$number_of_rows);

# $r_block->add_command('randomization_method <- "'.$self->get_randomization_method().'"');

 # if ($self->has_randomization_seed()){
 #   $r_block->add_command('randomization_seed <- '.$self->get_randomization_seed());
 #   $r_block->add_command('augmented<-design.dau(control_trt,trt,number_of_blocks,serie=1,kinds=randomization_method, seed=randomization_seed)');
 # }
 # else {
 #   $r_block->add_command('augmented<-design.dau(control_trt,trt,number_of_blocks,serie=1,kinds=randomization_method)');
 # }

 #$r_block->add_command('test.ma<-design.dma(entries=c(seq(1,330,1)),chk.names=c(seq(1,4,1)),num.rows=9, num.cols=NULL, num.sec.chk=3)');

# $r_block->add_command('test.ma<-design.dma(entries=trt,chk.names=control_trt,num.rows=number_of_rows, num.cols=NULL, num.sec.chk=3)');
 
#  $r_block->add_command('test.ma<-design.dma.0(entries=trt,chk.names=control_trt, nFieldRow=number_of_rows)');

   $r_block->add_command('test.ma<-design.dma(entries=trt,chk.names=control_trt, nFieldRow=number_of_rows)');

#  design.dma.0(entries=c(seq(1,300,1)),chk.names= c(seq(1,4,1)),nFieldRow=10)

# $r_block->add_command('augmented<-design.dau(control_trt,trt,number_of_blocks,serie=1,kinds=randomization_method)');

# $r_block->add_command('augmented<-augmented$book'); #added for agricolae 1.1-8 changes in output

  $r_block->add_command('augmented<-test.ma[[2]]'); #added for agricolae 1.1-8 changes in output
#  $r_block->add_command('print(augmented)'); 
  $r_block->add_command('augmented<-as.matrix(augmented)');
 # $r_block->add_command('augmented<-as.data.frame(augmented)');

 #  $r_block<-add_command('colnames(augmented)[2]<-"plots"');
 #  $r_block<-add_command('colnames(augmented)[3]<-"trt"');
 #  $r_block<-add_command('colnames(augmented)[7]<-"block"');

    my @commands = $r_block->read_commands();
    print STDERR join "\n", @commands;
    print STDERR "\n";

  $r_block->run_block();

  $result_matrix = R::YapRI::Data::Matrix->read_rbase( $rbase,'r_block','augmented');

  @plot_numbers = $result_matrix->get_column("Plot");
  @row_numbers = $result_matrix->get_column("Row");
  @col_numbers = $result_matrix->get_column("Col");
  @block_row_numbers=$result_matrix->get_column("Row.Blk");
  @block_col_numbers=$result_matrix->get_column("Col.Blk");
  @block_numbers = $result_matrix->get_column("Blk");
  @stock_names = $result_matrix->get_column("Entry");
  @check_names=$result_matrix->get_column("Check");

#Row.Blk Col.Blk

  @converted_plot_numbers=@{_convert_plot_numbers($self,\@plot_numbers)};

  for (my $i = 0; $i < scalar(@converted_plot_numbers); $i++) {
    my %plot_info;

    $plot_info{'row_number'} =$row_numbers[$i];
    $plot_info{'col_number'} =$col_numbers[$i];
    $plot_info{'check_name'} =$check_names[$i];
    $plot_info{'stock_name'} = $stock_names[$i];
    $plot_info{'block_number'} = $block_numbers[$i];
    $plot_info{'block_row_number'}=$block_row_numbers[$i];
    $plot_info{'block_col_number'}=$block_col_numbers[$i];
    $plot_info{'plot_name'} = $converted_plot_numbers[$i];
    $plot_info{'is_a_control'} = exists($control_names_lookup{$stock_names[$i]});
    $madii_design{$converted_plot_numbers[$i]} = \%plot_info;
  }

  %madii_design = %{_build_plot_names($self,\%madii_design)};

#  return \%augmented_design;

 #call R code and create design data structure

 return \%madii_design;

#=cut

}

sub _get_madiii_design {

    my $self = shift;
    my %madiii_design;
 
    my $rbase = R::YapRI::Base->new();
  
    my @stock_list;
    my @control_list;
    my $maximum_block_size;
    my $number_of_blocks;

    my $number_of_rows;
    my $number_of_rows_per_block;
    my $number_of_cols_per_block;
    my $number_of_cols;


    my $stock_data_matrix;
    my $control_stock_data_matrix;
    my $r_block;
    my $result_matrix;
    my @plot_numbers;
    my @stock_names;
    my @block_numbers;
    my @converted_plot_numbers;
    my %control_names_lookup;
    my $stock_name_iter;
    my @row_numbers;
    my @check_names;

    my @col_numbers;
    my @block_row_numbers;
    my @block_col_numbers;


  if ($self->has_stock_list()) {
    @stock_list = @{$self->get_stock_list()};
  } else {
    die "No stock list specified\n";
  }

  if ($self->has_control_list()) {
    @control_list = @{$self->get_control_list()};
    %control_names_lookup = map { $_ => 1 } @control_list;
    foreach $stock_name_iter (@stock_names) {
      if (exists($control_names_lookup{$stock_name_iter})) {
	die "Names in stock list cannot be used also as controls\n";
      }
    }
  } else {
    die "No list of control stocks specified.  Required for augmented design.\n";
  }


    if ($self->has_number_of_rows()) {
    $number_of_rows = $self->get_number_of_rows();
    } else {
    die "Number of rows not specified\n";
    }

    if ($self->has_block_row_numbers()) {
    $number_of_rows_per_block = $self->get_block_row_numbers();
    } else {
    die "Number of block row not specified\n";
    }

    if ($self->has_block_col_numbers()) {
    $number_of_cols_per_block = $self->get_block_col_numbers();
    } else {
    die "Number of block col not specified\n";
    }

    if ($self->has_number_of_cols()) {
    $number_of_cols = $self->get_number_of_cols();
    } else {
    die "Number of blocks not specified\n";
    }

    #system("R --slave --args $tempfile $tempfile_out < R/MADII_layout_function.R");
#     system("R --slave < R/MADII_layout_function.R");


#    if ($self->has_maximum_row_number()) {
#    $maximum_row_number = $self->get_maximum_row_number();
#    if ($maximum_block_size <= scalar(@control_list)) {
#      die "Maximum block size must be greater the number of control stocks for augmented design\n";
#    }
#    if ($maximum_block_size >= scalar(@control_list)+scalar(@stock_list)) {
#      die "Maximum block size must be less than the number of stocks plus the number of controls for augmented design\n";
#    }
#    $number_of_blocks = ceil(scalar(@stock_list)/($maximum_block_size-scalar(@control_list)));
#
#  } else {
#    die "No block size specified\n";
#  }


#  if ($self->has_maximum_block_size()) {
#    $maximum_block_size = $self->get_maximum_block_size();
#    if ($maximum_block_size <= scalar(@control_list)) {
#      die "Maximum block size must be greater the number of control stocks for augmented design\n";
#    }
#    if ($maximum_block_size >= scalar(@control_list)+scalar(@stock_list)) {
#      die "Maximum block size must be less than the number of stocks plus the number of controls for augmented design\n";
#    }
#    $number_of_blocks = ceil(scalar(@stock_list)/($maximum_block_size-scalar(@control_list)));
#  } else {
#    die "No block size specified\n";
#  }

#=comment

  print "@stock_list\n";

 
  $stock_data_matrix =  R::YapRI::Data::Matrix->new(
						       {
							name => 'stock_data_matrix',
							rown => 1,
							coln => scalar(@stock_list),
							data => \@stock_list,
						       }
						      );
  $control_stock_data_matrix =  R::YapRI::Data::Matrix->new(
						       {
							name => 'control_stock_data_matrix',
							rown => 1,
							coln => scalar(@control_list),
							data => \@control_list,
						       }
						      );


  $r_block = $rbase->create_block('r_block');
  $stock_data_matrix->send_rbase($rbase, 'r_block');
  $control_stock_data_matrix->send_rbase($rbase, 'r_block');

 #$r_block->add_command('library(agricolae)');

  $r_block->add_command('library(MAD)');

  $r_block->add_command('trt <- as.array(stock_data_matrix[1,])');
  $r_block->add_command('control_trt <- as.array(control_stock_data_matrix[1,])');

#  $r_block->add_command('acc<-c(seq(1,330,1))');
#  $r_block<-add_command('chk<-c(seq(1,4,1))');

#  $r_block->add_command('trt <- acc');
#  $r_block->add_command('control_trt <- chk');
#  $r_block->add_command('number_of_blocks <- '.$number_of_blocks);

# $r_block->add_command('randomization_method <- "'.$self->get_randomization_method().'"');

 # if ($self->has_randomization_seed()){
 #   $r_block->add_command('randomization_seed <- '.$self->get_randomization_seed());
 #   $r_block->add_command('augmented<-design.dau(control_trt,trt,number_of_blocks,serie=1,kinds=randomization_method, seed=randomization_seed)');
 # }
 # else {
 #   $r_block->add_command('augmented<-design.dau(control_trt,trt,number_of_blocks,serie=1,kinds=randomization_method)');
 # }

 #$r_block->add_command('test.ma<-design.dma(entries=c(seq(1,330,1)),chk.names=c(seq(1,4,1)),num.rows=9, num.cols=NULL, num.sec.chk=3)');
 
  $r_block->add_command('number_of_rows <- '.$number_of_rows);
  $r_block->add_command('number_of_cols <- '.$number_of_cols);
  $r_block->add_command('number_of_rows_per_block <- '.$number_of_rows_per_block); 
  $r_block->add_command('number_of_cols_per_block <- '.$number_of_cols_per_block);

  $r_block->add_command('test.ma<-design.dma(entries=trt,chk.names=control_trt,nFieldRow=number_of_rows,nFieldCols=number_of_cols,nRowsPerBlk=number_of_rows_per_block, nColsPerBlk=number_of_cols_per_block)');


 # $r_block->add_command('test.ma<-design.dma(entries=trt,chk.names=control_trt,num.rows=9, num.cols=NULL, num.sec.chk=3)');

  #$r_block->add_command('test.ma<-design.dma(entries=trt,chk.names=control_trt,num.rows=9, num.cols=NULL, num.sec.chk=3)');

# $r_block->add_command('augmented<-design.dau(control_trt,trt,number_of_blocks,serie=1,kinds=randomization_method)');

# $r_block->add_command('augmented<-augmented$book'); #added for agricolae 1.1-8 changes in output

  $r_block->add_command('augmented<-test.ma[[2]]'); #added for agricolae 1.1-8 changes in output
  $r_block->add_command('augmented<-as.matrix(augmented)');

#  $r_block<-add_command('colnames(augmented)[2]<-"plots"');
#  $r_block<-add_command('colnames(augmented)[3]<-"trt"');
#  $r_block<-add_command('colnames(augmented)[7]<-"block"');


   my @commands = $r_block->read_commands();
   print STDERR join "\n", @commands;
   print STDERR "\n";


  $r_block->run_block();

  $result_matrix = R::YapRI::Data::Matrix->read_rbase( $rbase,'r_block','augmented');

  @plot_numbers = $result_matrix->get_column("Plot");
  @row_numbers = $result_matrix->get_column("Row");
  @col_numbers = $result_matrix->get_column("Col");
  @block_row_numbers=$result_matrix->get_column("Row.Blk");
  @block_col_numbers=$result_matrix->get_column("Col.Blk");
  @block_numbers = $result_matrix->get_column("Blk");
  @stock_names = $result_matrix->get_column("Entry");
  @check_names=$result_matrix->get_column("Check");


#Row.Blk Col.Blk



  @converted_plot_numbers=@{_convert_plot_numbers($self,\@plot_numbers)};

  for (my $i = 0; $i < scalar(@converted_plot_numbers); $i++) {
    my %plot_info;

    $plot_info{'row_number'} =$row_numbers[$i];
    $plot_info{'col_number'} =$col_numbers[$i];
    $plot_info{'check_name'} =$check_names[$i];
    $plot_info{'stock_name'} = $stock_names[$i];
    $plot_info{'block_number'} = $block_numbers[$i];
    $plot_info{'block_row_number'}=$block_row_numbers[$i];
    $plot_info{'block_col_number'}=$block_col_numbers[$i];
    $plot_info{'plot_name'} = $converted_plot_numbers[$i];
    $plot_info{'is_a_control'} = exists($control_names_lookup{$stock_names[$i]});
    $madiii_design{$converted_plot_numbers[$i]} = \%plot_info;
  }

  %madiii_design = %{_build_plot_names($self,\%madiii_design)};

#  return \%augmented_design;

 #call R code and create design data structure

 return \%madiii_design;

#=cut

}

sub _get_madiv_design {

    my $self = shift;
    my %madiv_design;
 
    my $rbase = R::YapRI::Base->new();
  
    my @stock_list;
    my @control_list;
    my $maximum_block_size;
    my $number_of_blocks;

    my $number_of_rows;
    my $number_of_rows_per_block;
    my $number_of_cols_per_block;
    my $number_of_cols;


    my $stock_data_matrix;
    my $control_stock_data_matrix;
    my $r_block;
    my $result_matrix;
    my @plot_numbers;
    my @stock_names;
    my @block_numbers;
    my @converted_plot_numbers;
    my %control_names_lookup;
    my $stock_name_iter;
    my @row_numbers;
    my @check_names;

    my @col_numbers;
    my @block_row_numbers;
    my @block_col_numbers;


  if ($self->has_stock_list()) {
    @stock_list = @{$self->get_stock_list()};
  } else {
    die "No stock list specified\n";
  }

  if ($self->has_control_list()) {
    @control_list = @{$self->get_control_list()};
    %control_names_lookup = map { $_ => 1 } @control_list;
    foreach $stock_name_iter (@stock_names) {
      if (exists($control_names_lookup{$stock_name_iter})) {
	die "Names in stock list cannot be used also as controls\n";
      }
    }
  } else {
    die "No list of control stocks specified.  Required for augmented design.\n";
  }


    if ($self->has_number_of_rows()) {
    $number_of_rows = $self->get_number_of_rows();
    } else {
    die "Number of rows not specified\n";
    }

    if ($self->has_block_row_numbers()) {
    $number_of_rows_per_block = $self->get_block_row_numbers();
    } else {
    die "Number of block row not specified\n";
    }

  #  if ($self->has_block_col_numbers()) {
  #  $number_of_cols_per_block = $self->get_block_col_numbers();
  #  } else {
  #  die "Number of block col not specified\n";
  #  }

  #  if ($self->has_number_of_cols()) {
  #  $number_of_cols = $self->get_number_of_cols();
  #  } else {
  #  die "Number of blocks not specified\n";
  #  }

    #system("R --slave --args $tempfile $tempfile_out < R/MADII_layout_function.R");
#     system("R --slave < R/MADII_layout_function.R");


#    if ($self->has_maximum_row_number()) {
#    $maximum_row_number = $self->get_maximum_row_number();
#    if ($maximum_block_size <= scalar(@control_list)) {
#      die "Maximum block size must be greater the number of control stocks for augmented design\n";
#    }
#    if ($maximum_block_size >= scalar(@control_list)+scalar(@stock_list)) {
#      die "Maximum block size must be less than the number of stocks plus the number of controls for augmented design\n";
#    }
#    $number_of_blocks = ceil(scalar(@stock_list)/($maximum_block_size-scalar(@control_list)));
#
#  } else {
#    die "No block size specified\n";
#  }


#  if ($self->has_maximum_block_size()) {
#    $maximum_block_size = $self->get_maximum_block_size();
#    if ($maximum_block_size <= scalar(@control_list)) {
#      die "Maximum block size must be greater the number of control stocks for augmented design\n";
#    }
#    if ($maximum_block_size >= scalar(@control_list)+scalar(@stock_list)) {
#      die "Maximum block size must be less than the number of stocks plus the number of controls for augmented design\n";
#    }
#    $number_of_blocks = ceil(scalar(@stock_list)/($maximum_block_size-scalar(@control_list)));
#  } else {
#    die "No block size specified\n";
#  }

#=comment

  print "@stock_list\n";

 
  $stock_data_matrix =  R::YapRI::Data::Matrix->new(
						       {
							name => 'stock_data_matrix',
							rown => 1,
							coln => scalar(@stock_list),
							data => \@stock_list,
						       }
						      );
  $control_stock_data_matrix =  R::YapRI::Data::Matrix->new(
						       {
							name => 'control_stock_data_matrix',
							rown => 1,
							coln => scalar(@control_list),
							data => \@control_list,
						       }
						      );


  $r_block = $rbase->create_block('r_block');
  $stock_data_matrix->send_rbase($rbase, 'r_block');
  $control_stock_data_matrix->send_rbase($rbase, 'r_block');

 #$r_block->add_command('library(agricolae)');

  $r_block->add_command('library(MAD)');

  $r_block->add_command('trt <- as.array(stock_data_matrix[1,])');
  $r_block->add_command('control_trt <- as.array(control_stock_data_matrix[1,])');

#  $r_block->add_command('acc<-c(seq(1,330,1))');
#  $r_block<-add_command('chk<-c(seq(1,4,1))');

#  $r_block->add_command('trt <- acc');
#  $r_block->add_command('control_trt <- chk');
#  $r_block->add_command('number_of_blocks <- '.$number_of_blocks);

# $r_block->add_command('randomization_method <- "'.$self->get_randomization_method().'"');

 # if ($self->has_randomization_seed()){
 #   $r_block->add_command('randomization_seed <- '.$self->get_randomization_seed());
 #   $r_block->add_command('augmented<-design.dau(control_trt,trt,number_of_blocks,serie=1,kinds=randomization_method, seed=randomization_seed)');
 # }
 # else {
 #   $r_block->add_command('augmented<-design.dau(control_trt,trt,number_of_blocks,serie=1,kinds=randomization_method)');
 # }

 #$r_block->add_command('test.ma<-design.dma(entries=c(seq(1,330,1)),chk.names=c(seq(1,4,1)),num.rows=9, num.cols=NULL, num.sec.chk=3)');
 
  $r_block->add_command('number_of_rows <- '.$number_of_rows);
 # $r_block->add_command('number_of_cols <- '.$number_of_cols);
  $r_block->add_command('number_of_rows_per_block <- '.$number_of_rows_per_block); 
 # $r_block->add_command('number_of_cols_per_block <- '.$number_of_cols_per_block);

  #$r_block->add_command('test.ma<-design.dma(entries=trt,chk.names=control_trt,nFieldRow=number_of_rows,nFieldCols=number_of_cols,nRowsPerBlk=number_of_rows_per_block, nColsPerBlk=number_of_cols_per_block)');

  $r_block->add_command('test.ma<-design.dma(entries=trt,chk.names=control_trt,nFieldRow=number_of_rows,nRowsPerBlk=number_of_rows_per_block)');
 # $r_block->add_command('test.ma<-design.dma(entries=trt,chk.names=control_trt,num.rows=9, num.cols=NULL, num.sec.chk=3)');

  #$r_block->add_command('test.ma<-design.dma(entries=trt,chk.names=control_trt,num.rows=9, num.cols=NULL, num.sec.chk=3)');

# $r_block->add_command('augmented<-design.dau(control_trt,trt,number_of_blocks,serie=1,kinds=randomization_method)');

# $r_block->add_command('augmented<-augmented$book'); #added for agricolae 1.1-8 changes in output

  $r_block->add_command('augmented<-test.ma[[2]]'); #added for agricolae 1.1-8 changes in output
  $r_block->add_command('augmented<-as.matrix(augmented)');

#  $r_block<-add_command('colnames(augmented)[2]<-"plots"');
#  $r_block<-add_command('colnames(augmented)[3]<-"trt"');
#  $r_block<-add_command('colnames(augmented)[7]<-"block"');


   my @commands = $r_block->read_commands();
   print STDERR join "\n", @commands;
   print STDERR "\n";


  $r_block->run_block();

  $result_matrix = R::YapRI::Data::Matrix->read_rbase( $rbase,'r_block','augmented');

  @plot_numbers = $result_matrix->get_column("Plot");
  @row_numbers = $result_matrix->get_column("Row");
  @col_numbers = $result_matrix->get_column("Col");
  @block_row_numbers=$result_matrix->get_column("Row.Blk");
  @block_col_numbers=$result_matrix->get_column("Col.Blk");
  @block_numbers = $result_matrix->get_column("Blk");
  @stock_names = $result_matrix->get_column("Entry");
  @check_names=$result_matrix->get_column("Check");


#Row.Blk Col.Blk



  @converted_plot_numbers=@{_convert_plot_numbers($self,\@plot_numbers)};

  for (my $i = 0; $i < scalar(@converted_plot_numbers); $i++) {
    my %plot_info;

    $plot_info{'row_number'} =$row_numbers[$i];
    $plot_info{'col_number'} =$col_numbers[$i];
    $plot_info{'check_name'} =$check_names[$i];
    $plot_info{'stock_name'} = $stock_names[$i];
    $plot_info{'block_number'} = $block_numbers[$i];
    $plot_info{'block_row_number'}=$block_row_numbers[$i];
    $plot_info{'block_col_number'}=$block_col_numbers[$i];
    $plot_info{'plot_name'} = $converted_plot_numbers[$i];
    $plot_info{'is_a_control'} = exists($control_names_lookup{$stock_names[$i]});
    $madiv_design{$converted_plot_numbers[$i]} = \%plot_info;
  }

  %madiv_design = %{_build_plot_names($self,\%madiv_design)};

#  return \%augmented_design;

 #call R code and create design data structure

 return \%madiv_design;

#=cut

}

sub _convert_plot_numbers {
  my $self = shift;
  my $plot_numbers_ref = shift;
  my @plot_numbers = @{$plot_numbers_ref};
  for (my $i = 0; $i < scalar(@plot_numbers); $i++) {
    my $plot_number;
    my $first_plot_number;
    if ($self->has_plot_start_number()){
      $first_plot_number = $self->get_plot_start_number();
    } else {
      $first_plot_number = 1;
    }
    if ($self->has_plot_number_increment()){
      $plot_number = $first_plot_number + ($i * $self->get_plot_number_increment());
    }
    else {
      $plot_number = $first_plot_number + $i;
    }
    $plot_numbers[$i] = $plot_number;
  }
  return \@plot_numbers;
}

sub _build_plot_names {
  my $self = shift;
  my $design_ref = shift;
  my %design = %{$design_ref};
  my $prefix = '';
  my $suffix = '';
  my $trial_name = $self->get_trial_name;
  if ($self->has_plot_name_prefix()) {
    $prefix = $self->get_plot_name_prefix();
  }
  if ($self->has_plot_name_suffix()) {
    $suffix = $self->get_plot_name_suffix();
  }
  foreach my $key (keys %design) {
	$trial_name ||="";
    $design{$key}->{plot_name} = $trial_name.$prefix.$key.$suffix;
    $design{$key}->{plot_number} = $key;
  }
  return \%design;
}

1;
