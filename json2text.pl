#!/usr/bin/perl -w

use strict;
use JSON; # imports encode_json, decode_json, to_json and from_json.
use Data::Dumper;

#my($param) = shift(@ARGV);
#die unless ( $param );

my($json);
foreach $json ( <STDIN> ) {
	my($hp) = undef;
	eval { $hp = decode_json $json; };
	next unless ( $hp );
	#print Dumper(\$hp);
	foreach ( @ARGV ) {
		my($res) = $hp->{$_};
	#if ( defined($hp->{$param}) ) {
		print "$_: $res , ";
	}
	print "\n";

}
