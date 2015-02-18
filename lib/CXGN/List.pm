
package CXGN::List;

use Moose;

has 'dbh' => ( isa => 'DBI::db',
	       is => 'rw',
	       required => 1,
    );

has 'list_id' => (isa => 'Int',
		  is => 'ro',
		  required => 1,
    );

has 'owner' => (isa => 'Int',
		is => 'rw',
    );

has 'name' => (isa => 'Str',
	       is => 'rw',
    );

has 'description' => (isa => 'Str',
		      is => 'rw',
    );

has 'type' => (isa => 'Str',
	       is => 'rw',
    );

has 'elements' => (isa => 'ArrayRef',
		   is => 'rw',
    );

# class method: Use like so: CXGN::List::create_list
sub create_list { 
    my $dbh = shift;
    my ($name, $desc, $owner) = @_;
    my $new_list_id;
    eval { 
    my $q = "INSERT INTO sgn_people.list (name, description, owner) VALUES (?, ?, ?) RETURNING list_id";
    my $h = $dbh->prepare($q);
    $h->execute($name, $desc, $owner);
    ($new_list_id) = $h->fetchrow_array();
    print STDERR "NEW LIST using returning = $new_list_id\n";
    
    $q = "SELECT list.name, list.description, type_id, cvterm.name, list_id FROM sgn_people.list LEFT JOIN cvterm ON (type_id=cvterm_id)";
    $h = $dbh->prepare($q);
    $h->execute();
    while (my @data = $h->fetchrow_array()) {
	print STDERR join ", ", @data;
	print STDERR "\n";
    }
    ###END TEST
    }; 
    if ($@) { 
	print "AN ERROR OCCURRED: $@\n";
	return;
    }
    return $new_list_id;
}

# class method! see above
sub all_types { 
    my $dbh = shift;
    my $q = "SELECT cvterm_id, cvterm.name FROM cvterm JOIN cv USING(cv_id) WHERE cv.name = 'list_types' ";
    my $h = $dbh->prepare($q);
    $h->execute();
    my @all_types = ();
    while (my ($id, $name) = $h->fetchrow_array()) { 
	push @all_types, [ $id, $name ];
    }
    return \@all_types;

}

# class method! (see above)
#
sub available_lists { 
    my $dbh = shift;
    my $owner = shift;
    my $requested_type = shift;

    my $q = "SELECT list_id, list.name, description, count(distinct(list_item_id)), type_id, cvterm.name FROM sgn_people.list left join sgn_people.list_item using(list_id) LEFT JOIN cvterm ON (type_id=cvterm_id) WHERE owner=? GROUP BY list_id, list.name, description, type_id, cvterm.name ORDER BY list.name";
    my $h = $dbh->prepare($q);
    $h->execute($owner);

    my @lists = ();
    while (my ($id, $name, $desc, $item_count, $type_id, $type) = $h->fetchrow_array()) { 
	if ($requested_type) { 
	    if ($type && ($type eq $requested_type)) { 
		push @lists, [ $id, $name, $desc, $item_count, $type_id, $type ];
	    }
	}
	else { 
	    push @lists, [ $id, $name, $desc, $item_count, $type_id, $type ];
	}
    }
    return \@lists;
}

sub delete_list { 
    my $dbh = shift;
    my $list_id = shift;
    
    my $q = "DELETE FROM sgn_people.list WHERE list_id=?";
    
    eval { 
	my $h = $dbh->prepare($q);
	$h->execute($list_id);
    };
    if ($@) { 
	return "An error occurred while deleting list with id $list_id: $@";
    }
    return 0;
}


sub exists_list { 
    my $dbh = shift;
    my $name = shift;
    my $owner = shift;

    my $q = "SELECT list_id FROM sgn_people.list where name = ? and owner=?";
    my $h = $dbh->prepare($q);
    $h->execute($name, $owner);
    my ($list_id) = $h->fetchrow_array();

    if ($list_id) { 
	return $list_id;
    }
    return undef;
}


around 'BUILDARGS' => sub { 
    my $orig = shift;
    my $class = shift;
    my $args = shift;
    
    my $q = "SELECT content from sgn_people.list join sgn_people.list_item using(list_id) WHERE list_id=?";

    my $h = $args->{dbh}->prepare($q);
    $h->execute($args->{list_id});
    my @list = ();
    while (my ($content) = $h->fetchrow_array()) { 
	push @list, $content;
    }
    $args->{elements} = \@list;

    $q = "SELECT list.name, list.description, type_id, cvterm.name, owner FROM sgn_people.list LEFT JOIN cvterm ON (type_id=cvterm_id) WHERE list_id=?";
    $h = $args->{dbh}->prepare($q);
    $h->execute($args->{list_id});
    my ($name, $desc, $type_id, $list_type, $owner) = $h->fetchrow_array();

    $args->{name} = $name || '';
    $args->{description} = $desc || '';
    $args->{type} = $list_type || '';
    $args->{owner} = $owner;

    return $class->$orig($args);
};

after 'name' => sub { 
    my $self = shift;
    my $name = shift;

    if (!$name) { return; }

    my $q = "SELECT list_id FROM sgn_people.list where name=? and owner=?";
    my $h = $self->dbh->prepare($q);
    $h->execute($name, $self->owner());
    my ($old_list) = $h->fetchrow_array();
    if ($old_list) { 
	return "The list name $name already exists. Please choose another name.";
    }

    $q = "UPDATE sgn_people.list SET name=? WHERE list_id=?"; #removed "my"
    $h = $self->dbh->prepare($q);

    eval { 
	$h->execute($name, $self->list_id());
    };
    if ($@) { 
	return "An error occurred updating the list name ($@)";
    }
    return 0;
};

after 'type' => sub { 
    my $self = shift;
    my $type = shift;

    if (!$type) { return; }

    my $q1 = "SELECT cvterm_id FROM cvterm WHERE name =?";
    my $h1 = $self->dbh->prepare($q1);
    $h1->execute($type);
    my ($cvterm_id) =$h1->fetchrow_array();
    if (!$cvterm_id) { 
	return "The specified type does not exist";
    }

    my $q = "SELECT owner FROM sgn_people.list WHERE list_id=?";
    my $h = $self->dbh()->prepare($q);
    $h->execute($self->list_id);

    eval { 
	$q = "UPDATE sgn_people.list SET type_id=? WHERE list_id=?";
	$h = $self->dbh->prepare($q);
	$h->execute($cvterm_id, $self->list_id);
    };
    if ($@) { 
	return "An error occurred while updating the type of list ".self->list_id." to $type. $@";
    }
    return 0;
};

after 'description' => sub { 
    my $self = shift;
    my $description = shift;
    
    if (!$description) { 
	print STDERR "NO desc provided... skipping!\n";
	return; 
    }

    my $q = "UPDATE sgn_people.list SET description=? WHERE list_id=?";
    my $h = $self->dbh->prepare($q);

    eval { 
	$h->execute($description, $self->list_id());
    };
    if ($@) { 
	return "An error occurred updating the list description ($@)";
    }
    return 0;
};
    

sub add_element {
    my $self = shift;
    my $element = shift;
    
    if ($self->exists_element($element)) { 
	return "The element $element already exists";
    }

    my $iq = "INSERT INTO sgn_people.list_item (list_id, content) VALUES (?, ?)";
    my $ih = $self->dbh()->prepare($iq);
    eval { 
	$ih->execute($self->list_id(), $element);
    };
    if ($@) { 
	return "An error occurred storing the element $element ($@)";
    }
    
    my $elements = $self->elements();
    push @$elements, $element;
    $self->elements($elements);
    return 0;
}

sub remove_element {
    my $self = shift;
    my $element = shift;

    my $h = $self->dbh()->prepare("DELETE FROM sgn_people.list_item where list_id=? and content=?");

    eval { 
	$h->execute($self->list_id(), $element);
    };
    if ($@) { 
	
	return "An error occurred while attempting to delete item $element";
    }
    my $elements = $self->elements();
    my @clean = grep(!/^$element$/, @$elements);
    $self->elements(\@clean);
    return 0;
}

sub remove_element_by_id { 
    my $self = shift;
    my $element_id = shift;
    my $h = $self->dbh()->prepare("SELECT content  FROM sgn_people.list_item where list_id=? and list_item_id=?");

    eval { 
	$h->execute($self->list_id(), $element_id);
    };
    if ($@) { 
	return "An error occurred while attempting to delete item $element_id";
    }
    my ($element) = $h->fetchrow_array();
    
    if (my $error = $self->remove_element($element)) { 
	return $error;
    }
    
    return 0;
}   

sub list_size { 
    my $self = shift;

    my $h = $self->dbh->prepare("SELECT count(*) from sgn_people.list_item WHERE list_id=?");
    $h->execute($self->list_id());
    my ($count) = $h->fetchrow_array();
    return $count;
}    

sub exists_element {
    my $self =shift;
    my $item = shift;
    
    my $q = "SELECT list_item_id FROM sgn_people.list join sgn_people.list_item using(list_id) where list.list_id =? and content = ?";
    my $h = $self->dbh()->prepare($q);
    $h->execute($self->list_id(), $item);
    my ($list_item_id) = $h->fetchrow_array();
    return $list_item_id;
}

sub type_id { 
    my $self =shift;
    
    my $q = "SELECT type_id FROM sgn_people.list WHERE list_id=?";
    my $h = $self->dbh()->prepare($q);
    $h->execute($self->list_id());
    my ($type_id) = $h->fetchrow_array();
    return $type_id;
}

sub retrieve_elements_with_ids { 
    my $self = shift;
    my $list_id = shift;

    my $q = "SELECT list_item_id, content from sgn_people.list_item  WHERE list_id=?";

    my $h = $self->dbh()->prepare($q);
    $h->execute($list_id);
    my @list = ();
    while (my ($id, $content) = $h->fetchrow_array()) { 
	push @list, [ $id, $content ];
    }
    return \@list;
}


1;
