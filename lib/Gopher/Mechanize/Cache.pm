package Gopher::Mechanize::Cache;

use warnings;
use strict;
use Carp;
use Net::Gopher::Utility 'check_params';







sub new
{
	my $invo  = shift;
	my $class = ref $invo || $invo;

	return bless({}, $class);
}





sub store
{
	my $self = shift;

	my ($key, $value) =
		check_params(['Key', 'Value'], \@_);

	$self->{$key} = $value;
}





sub retrieve
{
	my ($self, $key) = @_;

	return unless (defined $key);
	return $self->{$key} if (exists $self->{$key});
}





sub remove
{
	my ($self, $key) = @_;

	delete $self->{$key};
}




sub is_cached
{
	my ($self, $key) = @_;

	return 1 if (exists $self->{$key});
}

1;
