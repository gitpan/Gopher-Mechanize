
package Gopher::Mechanize::History;





sub new
{
	my $invo  = shift;
	my $class = ref $invo || $invo;

	my $self = {
		history        => [],
		current_indice => undef
	};

	bless($self, $class);
}





sub add
{
	my ($self, $url) = @_;

	push(@{$self->{'history'}}, $url);

	$self->{'current_indice'} = (@{$self->{'history'}} - 1);
}





sub current_request
{
	my $self = shift;

	return $self->{'history'}[$self->{'current_indice'}];
}





sub move_up
{
	my $self = shift;
	my $i    = $self->{'current_indice'} - 1;

	if ($self->{'history'}[$i] >= 0)
	{
		$self->{'current_indice'} = $i;

		return $self->{'history'}[$i];
	}
	else
	{
		return;
	}
}





sub move_down
{
	my $self = shift;
	my $i    = $self->{'current_indice'} + 1;

	if (defined $self->{'history'}[$i])
	{
		return $self->{'history'}[$i];
	}
	else
	{
		return;
	}
}

1;
