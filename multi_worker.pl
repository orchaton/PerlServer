#!/usr/bin/perl
use strict;
use warnings;

use CalculationKernel::Starter qw ( start_server );
use ExamplesGenerator::ServerGenerator; 

use IO::Socket;
use JSON::XS;
use feature 'say';

our $VERSION = '1.0';

my $config_file = './multi_worker.json';

sub get_config {
	my ($port, $server_name) = @_;
    my $config;

    say '[multi_worker] ' . $server_name;
    
    if (-e $config_file and !-z $config_file) {
        print 'Config File ' . $config_file . ' was found' . $/;
        open (my $fh, '<', $config_file) or
            print 'Can\'t open ' . $config_file . $/;
        
        my $lines;
        (chomp($_), $lines .= $_) while (<$fh>);

        my $src = JSON::XS::decode_json($lines);
        for (@$src) {
            $config = $_;
            last if ($config->{name} eq $server_name);
            $config = undef;
        }
        close($fh);
    }

    unless ($config) {
        print 'Config File ' . $config_file . ' not found' . $/;
        $config = { 
        	config => 
        	{
                LocalPort => $port,
                Reuse_Addr => 1,
                Listen => 50
            },
            clients => 50,
        };
    }

    $config->{config}{Type} = SOCK_STREAM;
    return $config;
}

my $calc_pid = fork();
unless ($calc_pid) {
	CalculationKernel::Starter::start_server(9100, get_config(9100, 'CalculationKernel'));
	exit(0);
}

my $gen_pid = fork();
unless ($gen_pid) {
	ExamplesGenerator::ServerGenerator::start_server(9101, get_config(9101, 'ExamplesGenerator'));
	exit(0);
}

$SIG{INT} = sub {
	kill 2, $gen_pid;
	kill 2, $calc_pid;
	until (waitpid(-1, 0) == -1) { };

	exit(0);
};

until (waitpid(-1, 0) == -1) { };
