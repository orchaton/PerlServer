#!/usr/bin/perl
package CalculationKernel::Starter;
use strict;
use warnings;

use IO::Socket;
use JSON::XS;

use POSIX qw ( mkfifo );

use CalculationKernel::Logger qw ( logger );

our $VERSION = '2.0';

use base qw(Exporter);
our @EXPORT_OK = qw( start_server );
our @EXPORT = qw( start_server );

use FindBin;

my $config_file = "$FindBin::Bin/./multi_worker.json";
my $log_file = "$FindBin::Bin/./log.pipe";
my $LOG;
my $log_pid;
my $server;

sub server_kill {

    print 'prepare to kill' . $/;
    kill 2, $log_pid;   # send SIGINT

    until (waitpid(-1, 0) == -1) {  }

    unlink($log_file);
    print 'Log file ' . $log_file . ' was deleted' . $/;

    close($server) if $server;

    close($LOG);
    exit(0);
}

sub get_config {
    my $port = shift;
    my $config;
    
    if (-e $config_file and !-z $config_file) {
        print 'Config File ' . $config_file . ' was found' . $/;

        open (my $fh, '<', $config_file) or
            print 'Can\'t open ' . $config_file . $/;
        
        my $lines;
        (chomp($_), $lines .= $_) while (<$fh>);

        my $src = JSON::XS::decode_json($lines);

        for (@$src) {
            $config = $_;
            last if ($config->{name} eq 'CalculationKernel');
            $config = undef;
        }

        close($fh);
    }

    unless ($config) {
        print 'Config File ' . $config_file . ' not found' . $/;
        $config = { config => 
            {
                LocalPort => $port,
                Reuse_Addr => 1,
                Listen => 2
            }
        };
    }

    $config->{config}{Type} = SOCK_STREAM;
    return $config;
}

sub _start_server {
    my $config = shift;
    my $server = IO::Socket::INET->new( %{$config->{config}} ) 
        or die 'Can\'t create server on port ' . $config->{config}{LocalPort} . ": $@ $/";

    print 'Server started' . $/;

    return $server;
}

sub start_logger {
    if (-e $log_file) {
        unlink($log_file);
    }

    mkfifo($log_file, 0770) 
        or die 'Can\'t create ' . "$log_file: $@ $/";

    print 'Log File ' . $log_file . ' created successfully' . $/; 

    logger($log_file);
}

sub start_server {
    my $port = shift;

    $SIG{INT} = \&server_kill;

    my $config = get_config($port);
    my $server = _start_server($config);

    ($LOG, $log_pid) = start_logger();


    until (waitpid(-1, 0) == -1) {  };
}

# start_server(9000);

1;