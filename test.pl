#!/usr/bin/perl 
use strict;
use Test::Simple tests => 4;
use Net::FileShare;

my $home_dir = `echo \$HOME`; 
chomp $home_dir;

## creating a server connection...
my $obj = Net::FileShare->new(
			_send_only => 1,
			_socket	   => 1,
			_directory => $home_dir,
			_debug	   => 1);

ok($obj->version eq '1.05', 'correct version');
ok(defined($obj) and ref $obj eq 'Net::FileShare', 'new() call works');
ok(eval '$obj->server_run_once', 'server_connection() works');
ok(eval '$obj->DESTROY_SELF', 'Destructor works');

