
package Gopher::Mechanize;

=head1 NAME

Gopher::Mechanize - A Gopherspace screen scraper

=head1 SYNOPSIS

 use Gopher::Mechanize;
 
 my $scraper = new Gopher::Mechanize;
 
 $scraper->navigate('gopher.quux.org');
 
 # to select an item from a menu using only its display string,
 # just use the one argument form of select_item():
 $scraper->select_item('Computers');
 
 # ...anything more complicated requires the named parameter syntax.
 # To select an item from a menu by its selector string:
 $scraper->select_item(Selector => '/Software/Gopher');
 
 # ...or by the order in which they appear in the menu. This selects
 # the tenth item from the menu:
 $scraper->select_item(N => 10);
 
 # specify as many options as you like for more accuracy:
 $scraper->select_item(
 	N        => 1,
 	ItemType => GIF_IMAGE_TYPE,
 	Display  => 'emacs-w3',
 	Selector => '/Software/Gopher/screenshots/emacs-w3.gif',
 	Host     => 'gopher.quux.org',
 	Port     => 70
 );
 
 $scraper->save_item(File => 'screenshot.gif');
 
 # now check your current working directory for 'screenshot.gif' :)
 
 
 
 # you can call all of the public methods from Net::Gopher::Response
 # on Gopher::Mechanize objects and they'll operate on the currently
 # viewed item:
 $scraper->navigate('gopher.floodgap.com');
 print $scraper->content;
 
 
 
 # You can access the underlying Net::Gopher object using the ng()
 # method:
 $scraper->ng->timeout(60);
 $scraper->ng->buffer_size(1024);
 
 # this bypasses Gopher::Mechanize, goes straight to the Net::Gopher
 # object, and thus wont get added to the item cache and item history:
 my $r = $scraper->ng->gopher_plus('rachael.dyndns.org');
 ...

=head1 DESCRIPTION

B<Gopher::Mechanize> is a screen scraper for the Internet Gopher protocol,
allowing you to pretend you're a human using a Gopher client in the same style
as UMN, Lynx, Netscape, Gnopher, or Forg directly from your Perl script,
selecting items from Gopher menu to Gopher menu, filling out +ASK forms, moving
back and forth, etc., etc.

A history of items selected and what order they were selected in is maintained,
as is a cache of the items themselves. You can move up and down (or back and
forth, which ever metaphor you prefer) the Gopherspace tree, reload cached
items, or even forgo the cache entirely.

Mechanize retains much of the behavior of B<Net::Gopher>. It accepts parameters
in the same style, inherits methods from B<Net::Gopher::Response>, and even
warns and dies using the same handlers.

Before reading on, you should make yourself familiar with B<Net::Gopher>.
See L<the Net::Gopher manpage|Net::Gopher>.

=cut

use 5.005;
use strict;
use warnings;
use vars qw($VERSION @ISA @EXPORT);
use base 'Exporter';
use Carp;
use URI;
use Gopher::Mechanize::Cache;
use Gopher::Mechanize::History;
use Net::Gopher;
use Net::Gopher::Exception;
use Net::Gopher::Utility 'check_params';
use Net::Gopher::Constants ':all';

$VERSION = '0.27';

push(@ISA, 'Net::Gopher::Exception');

# export the constants we've imported:
@EXPORT = @{ $Net::Gopher::Constants::EXPORT_TAGS{'all'} };






#==============================================================================#

=head2 new([OPTIONS])

This is the constructor method. It creates a new B<Gopher::Mechanize> object
and returns a reference to it. It also creates a new B<Net::Gopher> object that
is used internally by the item retrieval methods (C<navigate()> and
C<select_item()> for example) and can be accessed using the C<ng()> method.

This method takes the named parameters listed below. Any others will get passed
on to the internal B<Net::Gopher> object during its creation:

=over 4

=item Cache

I<Cache> specifies whether or not B<Gopher::Mechanize> should cache all items
downloaded. Supply a true value to turn caching on or a false value to turn it
off. By default, caching is on.

=back

See also the corresponding get/set
L<cache()|Gopher::Mechanize/cache([BOOLEAN])> method below.

=cut

sub new
{
	my $invo  = shift;
	my $class = ref $invo || $invo;

	my ($cache) = check_params(['Cache'], \@_);

	$cache = 1 unless (defined $cache);



	my $self = {
		ng           => new Net::Gopher (@_),
		cache        => $cache ? 1 : 0,
		current_item => undef,
		_history     => new Gopher::Mechanize::History,
		_cache       => new Gopher::Mechanize::Cache
	};

	bless($self, $class);
	return $self;
}





#==============================================================================#

=head2 ng([OBJECT])

This method is used to get at the internal B<Net::Gopher> object. If you have
your own B<Net::Gopher> object you want B<Gopher::Mechanize> to use, supply it
to this method and B<Gopher::Mechanize> will use that object instead.

=cut

sub ng
{
	my $self = shift;
	
	if (@_)
	{
		$self->{'ng'} = shift;
	}
	else
	{
		return $self->{'ng'};
	}
}





#==============================================================================#

=head1 ITEM RETRIEVAL METHODS

The following items can be used to retrieve items in Gopherspace. Each one
requests the specified item from a particular Gopherspace or raises a fatal
error (caught with the B<Net::Gopher> die handler) if they're unable to.
The retrieved item is added to the history, cached (if caching is enabled), and
becomes the currently viewed item. You can then examine it, modify it, save it,
etc., etc.

=head2 navigate(URL | OPTIONS)

The C<navigate()> method navigates to a resource in Gopherspace. It can be used
in one of two ways: you can supply either full or partial Gopher URL, or you
can supply the same arguments to it as you would the B<Net::Gopher::Request>
C<new()> constructor.

Typically, this is the first method you call on a B<Gopher::Mechanize> object
after initializing it.

=cut

sub navigate
{
	my $self = shift;

	my $request;
	if (@_ == 1)
	{
		$request = new Net::Gopher::Request ('URL', shift);
	}
	elsif (@_)
	{
		$request = new Net::Gopher::Request (@_);
	}
	else
	{
		return $self->call_die(
			join(' ',
				'You must specify either a URL to navigate to',
				'or a hash containing containing parameters',
				'describing the Gopherspace item to navigate',
				'to.'
			)
		);
	}



	$self->_request_item($request);

	$self->_history->add($request);
}





#==============================================================================#

=head2 reload()

This method re-requests the currently viewed item. If caching is on, then it
replaced the old cached version of item with a new one.

=cut

sub reload
{
	my $self = shift;

	my $request  = $self->_history->current_request;
	my $response = $self->ng->request($request);

	return $self->call_die($response->error) if ($response->is_error);



	$self->_cache->store(
		Key   => $request->as_url,
		Value => $response
	);
	$self->current_item($response);
}





#==============================================================================#

=head2 up()

This method moves up Gopherspace the tree, making the item you just previously
viewed the current item. If caching is on, then the cached version of the
previous item will be used; otherwise, it will be re-requested.

=cut

sub up
{
	my $self = shift;

	my $request = $self->_history->move_up
		or return $self->call_die(
			"Can't go up any further; you've reached the top of " .
			"the Gophersapce item tree."
		);

	$self->_request_item($request);
}





#==============================================================================#

=head2 back()

Same as C<up()>. Use this if you prefer the more WWW back/forward metaphor as
opposed to the Gopherspace/directory tree up/down metaphor.

=cut

sub back { return shift->up(@_) }





#==============================================================================#

=head2 down()

This method moves down the Gopherspace tree. This can only be called after a
call to either C<up()>/C<back()> If caching is on, then the cached version of
the item below will be used; otherwise, it will be re-requested.

=cut

sub down
{
	my $self = shift;

	my $request = $self->_history->move_down
		or return $self->call_die(
			"Can't go down any further; you've reached the " .
			"bottom of the Gophersapce item tree."
		);

	$self->_request_item($request);
}





#==============================================================================#

=head2 forward()

Same as C<down()>. Use this if you prefer the more WWW back/forward metaphor as
opposed to the Gopherspace/directory tree up/down metaphor.

=cut

sub forward { shift->down(@_) }





#==============================================================================#

=head2 select_item(DISPLAY | OPTIONS)

This method is used to select an item from a Gopher menu. You have two choices:
you can select an item from a menu by its display string, supplying that as
the only argument, or you can select an item based on that as well as one or
more of its other attributes by specifying them using named parameters.

The possible Name=value parameters are:

 N          = The N'th item in the menu.
 ItemType   = The first item of this type.
 Display    = The first item with this display string.
 Selector   = The first item with this selector string.
 Host       = The first item with this hostname field.
 Port       = The first item with this port field.
 GopherPlus = The first item with this Gopher+ string.

The value of any parameter can be either a string or regular expression
supplied using C<qr//> (it can tell the difference between the two).

For example, this tries to the select the item that's third on the menu, is a
GIF image, and has a display string of "Cat picture" or "Dog picture":

 $scraper->select_item(
	 N        => 3,
	 ItemType => GIF_IMAGE_TYPE,
	 Display  => qr/(?:Cat|Dog) picture/
 );

=cut

sub select_item
{
	my $self = shift;

	my $n;
	my %template;

	if (@_ == 1)
	{
		$template{'display'} = shift;
	}
	elsif (@_)
	{
		($n,
		 $template{'item_type'}, $template{'display'},
		 $template{'selector'}, $template{'host'},
		 $template{'port'}, $template{'gopher_plus'}) =
			check_params([qw(
				N
				ItemType
				Display
				Selector
				Host
				Port
				GopherPlus)], \@_
			);
	}
	else
	{
		return $self->call_die("You didn't specify an item to select");
	}

	my @items = $self->current_item->extract_items(
		ExceptTypes => INLINE_TEXT_TYPE
	);

	my $item_wanted;
	foreach my $item ($n ? $items[$n - 1] : @items)
	{
		my %values = (
			item_type   => $item->item_type,
			display     => $item->display,
			selector    => $item->selector,
			host        => $item->host,
			port        => $item->port,
			gopher_plus => $item->gopher_plus
		);

		my $is_not_wanted;
		foreach my $key (
			qw(item_type display selector host port gopher_plus))
		{
			next unless (defined $template{$key});

			if (ref $template{$key} eq 'Regexp')
			{
				$is_not_wanted++
					unless ($values{$key} =~ $template{$key});
			}
			else
			{
				$is_not_wanted++
					unless ($values{$key} eq $template{$key});
			}
		}

		unless ($is_not_wanted)
		{
			$item_wanted = $item;
			last;
		}
	}


	my $request = $item_wanted->as_request;

	$self->_request_item($request);
	$self->_history->add($request);
}





sub current_item
{
	my $self = shift;

	if (@_)
	{
		$self->{'current_item'} = shift;
	}
	elsif (defined $self->{'current_item'})
	{
		return $self->{'current_item'};
	}
	else
	{
		return $self->call_die(
			"To early to call this method: you haven't " .
			"requested any item yet."
		);
	}
}





sub save_item
{
	my $self = shift;

	my ($file) = check_params(['File'], \@_);



	open(FILE, "> $file")
		|| return $self->call_die(
			"Couldn't open file ($file) to save item to: $!"
		);

	binmode FILE unless ($self->current_item->is_text);
	print FILE $self->current_item->content;
	close FILE;
}





sub _request_item
{
	my ($self, $request) = @_;

	my $url = $request->as_url;

	my $response;
	if ($self->cache and $self->_cache->is_cached($url))
	{
		$response = $self->_cache->retrieve($url);
	}
	else
	{
		$response = $self->ng->request($request);

		return $self->call_die($response->error)
			if ($response->is_error);

		$self->_cache->store(
			Key   => $url,
			Value => $response
		);
	}

	$self->current_item($response);
}





sub cache
{
	my $self = shift;

	if (@_)
	{
		$self->{'cache'} = (shift) ? 1 : 0;
	}
	else
	{
		return $self->{'cache'};
	}
}





sub _cache   { return shift->{'_cache'} }
sub _history { return shift->{'_history'} }





# wrapper methods:
sub request               { shift->current_item->request(@_) }
sub raw_response          { shift->current_item->raw_response(@_) }
sub status_line           { shift->current_item->stauts_line(@_) }
sub status                { shift->current_item->status(@_) }
sub content               { shift->current_item->content(@_) }
sub extract_items         { shift->current_item->extract_items(@_) }
sub get_blocks            { shift->current_item->get_blocks(@_) }
sub as_xml                { shift->current_item->as_xml(@_) }
sub is_success            { shift->current_item->is_success(@_) }
sub is_error              { shift->current_item->is_error(@_) }
sub is_blocks             { shift->current_item->is_blocks(@_) }
sub is_gopher_plus        { shift->current_item->is_gopher_plus(@_) }
sub is_menu               { shift->current_item->is_menu(@_) }
sub is_terminated         { shift->current_item->is_terminated(@_) }
sub error                 { shift->current_item->error(@_) }
sub error_code            { shift->current_item->error_code(@_) }
sub error_admin           { shift->current_item->error_admin(@_) }
sub error_message         { shift->current_item->error_message(@_) }
sub extract_abstract      { shift->current_item->extract_abstract(@_) }
sub extract_admin         { shift->current_item->extract_admin(@_) }
sub extract_date_modified { shift->current_item->extract_date_modified(@_) }
sub extract_date_created  { shift->current_item->extract_date_created(@_) }
sub extract_date_expires  { shift->current_item->extract_date_expires(@_) }
sub extract_queries       { shift->current_item->extract_queries(@_) }
sub extract_description   { shift->current_item->extract_description(@_) }
sub extract_views         { shift->current_item->extract_views(@_) }

1;

__END__
