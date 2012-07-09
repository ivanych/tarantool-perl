use utf8;
use strict;
use warnings;

package DR::Tarantool::Iterator;
use Carp;
use Data::Dumper;

sub new {
    my ($class, $items, %opts) = @_;

    croak 'usage: DR::Tarantool::Iterator->new([$item1, $item2, ... ], %opts)'
        unless 'ARRAY' eq ref $items;


    my $self = bless { items   => $items } => ref($class) || $class;
    $self->_process_opts( %opts );
    $self;
}


=head2 clone

clone iterator object (doesn't clone items).
It is usable if You want to have iterator that have the other B<item_class>
and (or) B<item_constructor>.

=cut

sub clone {
    my ($self, %opts) = @_;
    $self = $self->new( $self->{items}, %opts );
    $self;
}


sub _process_opts {
    my ($self, %opts) = @_;
    $self->item_class(
        ('ARRAY' eq ref $opts{item_class}) ?
            @{ $opts{item_class} } : $opts{item_class}
    ) if exists $opts{item_class};

    $self->item_constructor($opts{item_constructor})
        if exists $opts{item_constructor};
    return $self;
}


=head2 count

returns count of items that are contained in iterator

=cut

sub count {
    my ($self) = @_;
    return scalar @{ $self->{items} };
}


=head2 item

returns one item from iterator by its number
(or croaks error for wrong numbers)

=cut

sub item {
    my ($self, $no) = @_;
    croak 'undefined item number' unless defined $no;
    croak 'wrong item number format (must be /^-?\d+$/)'
        unless $no =~ /^-?\d+$/;

    if ($no >= 0) {
        croak "iterator doesn't contain item with number $no"
            unless $no < $self->count;
    } else {
        croak "iterator doesn't contain item with number $no"
            unless $no >= -$self->count;
    }

    my $item = $self->{items}[ $no ];

    if (my $class = $self->item_class) {

        if (my $m = $self->item_constructor) {
            return $class->$m( $item, $no );
        }

        return bless $item => $class if ref $item;
        return bless \$item => $class;
    }

    return $self->{items}[ $no ];

}



=head2 next

returns next element from iterator (or B<undef> if eof).

    while(my $item = $iter->next) {
        do_something_with( $item );
    }

You can ask current element's number by function 'L<iter>'.

=cut

sub next :method {
    my ($self) = @_;
    my $iter = $self->iter;

    if (defined $self->{iter}) {
        return $self->item(++$self->{iter})
            if $self->iter < $#{ $self->{items} };
        delete $self->{iter};
        return undef;
    }

    return $self->item($self->{iter} = 0) if $self->count;
    return undef;
}


=head2 iter

returns current iterator index.

=cut

sub iter {
    my ($self) = @_;
    return $self->{iter};
}


=head2 reset

resets iterator index, returns previous index value.

=cut

sub reset :method {
    my ($self) = @_;
    return delete $self->{iter};
}


=head2 all

returns all elements from iterator.

    my @list = $iter->all;
    my $list_aref = $iter->all;

    my @abc_list = map { $_->abc } $iter->all;
    my @abc_list = $iter->all('abc');               # the same


    my @list = map { [ $_->abc, $_->cde ] } $iter->all;
    my @list = $iter->all('abc', 'cde');                # the same


    my @list = map { $_->abc + $_->cde } $iter->all;
    my @list = $iter->all(sub { $_[0]->abc + $_->cde }); # the same


=cut

sub all {
    my ($self, @items) = @_;

    return unless defined wantarray;
    my @res;

    local $self->{iter};


    if (@items == 1) {
        my $m = shift @items;

        while (my $i = $self->next) {
            push @res => $i->$m;
        }
    } elsif (@items) {
        while (my $i = $self->next) {
            push @res => [ map { $i->$_ } @items ];
        }
    } else {
        while (my $i = $self->next) {
            push @res => $i;
        }
    }

    return @res if wantarray;
    return \@res;
}



=head2 item_class

set/returns item class. If the value isn't defined, iterator will
bless fields into the class (or calls L<item_constructor> in the class
if L<item_constructor> is defined

=cut

sub item_class {
    my ($self, $v, $m) = @_;
    $self->item_constructor($m) if @_ > 2;
    return $self->{item_class} = ref($v) || $v if @_ > 1;
    return $self->{item_class};
}


=head2 item_constructor

set/returns item constructor. The value can be used only if L<item_class>
is defined.

=cut

sub item_constructor {
    my ($self, $v) = @_;
    return $self->{item_constructor} = $v if @_ > 1;
    return $self->{item_constructor};
}


=head2 push

push item into iterator.

=cut

sub push :method {
    my ($self, @i) = @_;
    push @{ $self->{items}} => @i;
    return $self;
}


1;