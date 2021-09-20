#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use List::Util qw[min];

my @int_list;
my $only_if;
foreach my $str (<>) {
	my $iname = $str;
	chomp $iname;
	next if $iname =~ /^\s*!/ || !$iname;
	$only_if ||= 1 if $iname =~ s/interface\s+//;
	next if $only_if && $str !~ /interface/;
	
	$iname =~ s/\s+.*//;
	push @int_list, $iname;
}

#print Dumper \@int_list;

my @r_part = split /, /, int_range(@int_list);
print "\n\n";
print "Получается более пяти частей. Диапазон будет разбит на несколько кусочков:\n" if @r_part>5;

while (@r_part) {
	my @part = @r_part[0 .. min(4, scalar @r_part - 1)];
	splice @r_part, 0, 5;
	printf "interface range %s\n", (join ", ", @part);
}
print "\n";



sub int_range {
	my @list = @_;
	my ( $prev_a, $prev_b, $range, $prev_range, $result ) = ( 0, 0, 0, 0, '' );

	@list = sort int_sort @list
	  ; # заранее сортирум список, дабы потом нам понадобится смотреть за последним элементом

	my @sort_list;
	foreach my $int ( sort { int_sort( $a, $b ) } @list ) {
		push @sort_list, $int;
	}

	foreach my $int (@sort_list) {
		my ( $a, $b );
		int_part( $int, \$a, \$b );

		$range = $prev_a eq $a && $prev_b + 1 == $b;

		# если не диапазон
		if ( !$prev_range && !$range ) {
			$result .= ", $a$b";
		}

		# если диапазон был и закончился
		elsif ( $prev_range && !$range ) {
			$result .= " - $prev_b";
			$result .= ", $a$b";
		}

		# если последний элемент
		if ( $sort_list[ @sort_list - 1 ] eq $int ) {
			if ($range) {
				$result .= " - $b";
			}
		}

		$prev_a     = $a;
		$prev_b     = $b;
		$prev_range = $range;
	}

	$result =~ s/^, //;
	return $result;
}


sub int_part {
	my ( $int, $a, $b ) = @_;
	$int =~ /^(.*?)(\d+)$/;
	( $$a, $$b ) = ( $1, $2 );
}

sub int_sort {
	my ( $int1, $int2 ) = @_;

	my @part1 = $int1 =~ /([a-z]+)/i ? $1 : '';
	push @part1, $int1 =~ /\d+/g;

	my @part2 = $int2 =~ /([a-z]+)/i ? $1 : '';
	push @part2, $int2 =~ /\d+/g;

	return $part1[0] cmp $part2[0] if $part1[0] ne $part2[0];

	#print join ";", @part2;print "<br>";

	shift @part1;
	shift @part2;

	foreach my $int1 (@part1) {
		my $int2 = shift @part2 || 0;

		return $int1 <=> $int2 if $int1 != $int2;
	}

	return 0;
}
