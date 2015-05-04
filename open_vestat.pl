#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage qw(pod2usage);


my $cpu_scheduler_path = '/proc/vz/fairsched';
my $blkio_sheduler_path = '/proc/vz/beancounter';

my $vzlist = "/usr/sbin/vzlist";
my @containers = get_all_running_containers();
my $cpu_data_storage = {};
my $cpu_consumption = {};


my @checks = ("disk_time", "disk_sectors", "cpu");

# sort by cpu by default
my $default_check_type = 'cpu';
my $check_type;
my $help;


GetOptions (
    "--help"        => \$help,          #Only help message
    "--sort-by=s"   => \$check_type,    #Our check_type
) or pod2usage( -message => "Error in command line argumtnts!\n", -verbose => 0, -noperldoc => 1, -exitval => 1,);



if ( $help ) {
    pod2usage(  -verbose => 3, -noperldoc => 1, -exitval => 0,);
}

if ( defined $check_type ) {
    if ( not grep {/^$check_type$/} @checks ) {
        pod2usage( -message => "Error - \"$check_type\" incorrect param! You can use cpu, disk_time or disk_sectors\n", -verbose => 0, -noperldoc => 1, -exitval => 1,);
    }
}
else {
    $check_type = $default_check_type;
}


for my $check (@checks) {
    $cpu_data_storage->{$check} = {};
    $cpu_consumption->{$check} = {};
}

while (1) {
    for my $check (@checks) {
        calc_resources_consumption(\@containers, $check);
    }   

    my $number_of_top_records = 20;
    my $counter = 0;

    print "We sort data by $check_type\n";
    my @keys_sorted_by_custom_parameter = reverse sort { 
        $cpu_consumption->{$check_type}->{$a} <=> $cpu_consumption->{$check_type}->{$b}
    } keys %{ $cpu_consumption->{$check_type} };

    for my $key (@keys_sorted_by_custom_parameter) {

        if ($counter > $number_of_top_records) {
            last;
        }

        # skip HWN
        if ($key eq 'hwn') {
            next;
        }

        print "$key:\t";
        for my $check (@checks) {
            unless ($cpu_consumption->{$check}->{hwn}) {
                next;
            }

            print "$check: " . sprintf("%.1f",$cpu_consumption->{$check}->{$key}/$cpu_consumption->{$check}->{hwn}*100) . " %\t";
        }
        print "\n";

        #print "process snapshot:\n";
        #print `vzprocess $key|sort -g -k 3|tail -n 1`;

        $counter++;
    }

    sleep(5);
    system('clear');
}

sub calc_resources_consumption {
    my @containers = @{ $_[0] };
    my $type = $_[1];

    my $main_path = '';
    my $value_path = '';

    if ($type eq 'cpu') {
        $main_path = $cpu_scheduler_path;
        $value_path = 'cpuacct.usage'; 
    } elsif ($type eq 'disk_time') {
        $main_path = $blkio_sheduler_path;
        $value_path = 'blkio.time';
    } elsif ($type eq 'disk_sectors') {
        $main_path = $blkio_sheduler_path;
        $value_path = 'blkio.sectors';
        #$value_path = 'blkio.io_serviced';
    } else {
        die "Unexpected type";
    }

    my $server_total_cpu_usage;
    if ( $type =~ /^disk/ ) {
        $server_total_cpu_usage = get_sum_disk_count("$main_path/$value_path");
    }
    else {
        $server_total_cpu_usage = read_file_contents("$main_path/$value_path");
    }

    if (defined $cpu_data_storage->{$type}->{hwn}) {
        $cpu_consumption->{$type}->{hwn} = $server_total_cpu_usage - $cpu_data_storage->{$type}->{hwn};
    }

    $cpu_data_storage->{$type}->{hwn} = $server_total_cpu_usage;

    for my $ct (@containers) {
        my $ct_cpu_usage;
        
        if ( $type =~ /^disk/ ) {
            $ct_cpu_usage = get_sum_disk_count("$main_path/$ct/$value_path");
        }
        else {
            $ct_cpu_usage = read_file_contents("$main_path/$ct/$value_path");
        }

        if (defined $cpu_data_storage->{$type}->{$ct}) {
            $cpu_consumption->{$type}->{$ct} = $ct_cpu_usage - $cpu_data_storage->{$type}->{$ct};
        }

        $cpu_data_storage->{$type}->{$ct} = $ct_cpu_usage;
    }

}

sub get_all_running_containers {
    my @containers = `$vzlist -H1`;
    chomp @containers;

    map {
        s/^\s+//;
        s/\s+$//;
    } @containers;

    return @containers;
}

sub get_sum_disk_count {
    my $file = shift;
    my $result = 0;

    open my $file_handler, "<", $file or return 0;
    while ( my $line = <$file_handler> ) {
        $result += (split /\s+/, $line )[1];
    }

    close $file_handler;

    return $result;
}

sub read_file_contents {
    my $path = shift;

    open my $fl, "<", $path or die "Can't open file";
    
    my $data = '';  
    while (<$fl>) {
        chomp;
        $data .= $_;  
    }    

    close $fl; 

    return $data;
}

__END__

=head1 NAME

open_vestat - script for output top 20 openvz containers for load on cpu/disk

=head1 SYNOPSIS

open_vestat [ --sort-by ( cpu | disk_time | disk_sectors ) ] [ --help ]

=head1 OPTIONS

=over 8

=item B<--help>

Print this message

=item B<--sort-by>

Sorting output for cpu or disk_time or disk_sectors

=back

=head1 DESCRIPTION

We use cgroups for count use cpu/blkio.time/blkio.sectors
