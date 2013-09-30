
package SGN::Controller::AJAX::List::Validate;

use Moose;

use Module::Pluggable require => 1;

sub validate { 
    my $self = shift;
    my $c = shift;
    my $type = shift;
    my $list = shift;

    foreach my $p ($self->plugins()) { 
        if ($type eq $p->name()) { 
	    my @missing = $p->validate($c, $list);
	}
    }
    
}

1;