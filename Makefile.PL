#!/usr/bin/perl -w
use strict;
use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
	NAME            => 'Gopher::Mechanize',
	VERSION_FROM    => 'lib/Gopher/Mechanize.pm',
	PL_FILES        => {},
	PREREQ_PM       => {
		'Net::Gopher' => 0.92,
	},
	($] >= 5.005
		? (ABSTRACT_FROM => 'lib/Gopher/Mechanize.pm',
		   AUTHOR        => 'William G. Davis ' .
		                    '<william_g_davis@users.sourceforge.net>')
		: ()
	),
);
