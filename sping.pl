#!/usr/bin/perl

use strict;
use warnings;
use diagnostics;

use Data::Dumper;
use English;
use Net::Ping;
use Getopt::Long;
use threads;
use threads::shared;

my $help;
my $only_fail;
my $file     = "/etc/known_hosts";
my $interval = 5;
my $icmp;
GetOptions(
    "help" => \$help,
    "n"    => \$only_fail,
	"icmp" => \$icmp,
    "f=s"  => \$file,
    "i=i"  => \$interval
);

if($icmp && !is_root()) {
    print "Для использования ICMP пингов нужны рутовые права: sudo sping\n";
	exit;
}


my $filter = shift || '.*';

if ($help) {
    print_help();
    exit;
}

my $hfile;

die
"Не удалось открыть файл с устройствами '$file': $ERRNO\n"
  unless open $hfile, $file;

my $index : shared = 0;
my $list = shared_clone(device_list( $filter, $hfile ));

#my $q = $list->[1];
#print Dumper $q;
#print "[1]\n" if is_shared($q);
#exit;

die "Не выбрано ни одного устройства\n" unless $list;

while (1) {
    #my $start_time = time;
	
    ping_list();
    clear_screen();
    print_result( $only_fail );
    #my $run_time = int( ( time - $start_time ) );
	#print "Время выполнения: $run_time сек.";

    sleep($interval);
    $index = 0;
}

sub print_result {
    my ( $only_fail ) = @_;

    my $fail_count = 0;
    my $total;
    foreach my $host ( @$list ) {
        $total++;
        my $result = $host->{last};
        $fail_count++ unless $result;

        my $res_str   = $result ? 'Ok' : "Fail";
        my $esc_seq   = "\x1b[";
        my $col_reset = $esc_seq . "39;49;00m";
        $res_str = $esc_seq . "31;01m" . $res_str . $col_reset
          if !$result;

        my $summary = sprintf("%d/%d/%.2f%%", $host->{ok}, $host->{fail}, $host->{fail} / ($host->{ok} + $host->{fail})* 100);
        printf "%-50s %s (%s)\n", cut_vrf($host->{host}), $res_str, $summary
          if ( $only_fail && !$result ) || !$only_fail;
    }

    print "\nПроблемных: $fail_count; Всего: $total\n";
}

sub ping_list {
    #my ($list) = @_;

    my @threads;
    my $num_threads = 10;
    for my $t ( 1 .. $num_threads ) {
        push @threads, threads->create( \&ping_host );
    }

    foreach my $thread (@threads) {
        $thread->join();
    }
}

sub ping_host {

    #my ( $list ) = @_;

    my $type = $icmp ? "icmp" : "udp";
	my $ping = Net::Ping->new( $type, 2 );

    while (1) {

        my $seq;
	# Берём следующий номер в списке
        {
		lock $index;
		$seq = $index++;
	}

        # Если список кончился, заканчиваем
        last if $seq >= @$list;

        my $host = $list->[$seq];
		my $result = $ping->ping( $host->{host} );

		#my $th = threads->self();
		#print $th->tid()."\n";

        $host->{last} = $result;

        if ($result) {
            $host->{ok}++;
        }
        else {
            $host->{fail}++;
        }
    }
}

sub cut_vrf {
    my $host = shift;
    $host =~ s/.krw.rzd//;

    return $host;
}

sub device_list {
    my ( $filter, $hfile ) = @_;

    my @list;
    foreach my $str (<$hfile>) {
        chomp $str;
        next unless $str;
        next if $str =~ /^#/;
        if ( $str =~ /$filter/i ) {
            my %data = (host => $str, ok => 0, fail => 0);
            push @list, \%data;
        }
    }
    return @list ? \@list : undef;
}

sub clear_screen {
    print "\033[2J";      #clear the screen
    print "\033[0;0H";    #jump to 0,0
}

sub is_root {
    return $EFFECTIVE_USER_ID == 0;
	
}

sub print_help {
    print <<HELP
	Описание:
		Массовое, циклическое пингование устройств	

	Использование:
		sping [-f file_name] [-n] [-i interval] DEVICE_NAME_FILTER
			DEVICE_NAME_FILTER фильтр имен устройств, по умолчанию все устройства
			-f имя файла со списком устройств, по умолчанию /etc/known_hosts
			-n показывать только устройства которые не ответили на пинг
			-i интервал в секундах между циклами пингов, по умолчанию 5 сек
			-icmp использовать ICMP пинги (по умолчанию UDP). Для использования опции нужны рутовые права.

	Примеры:
		sping ilansk
HELP
}
