#!/usr/bin/perl -w
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { 
        push @INC, '.'; 
	$| = 1; 
	print "1..7\n"; 
      }

END {
     print "not ok 1\n" unless $loaded;
     unshift @INC, '.';
     }

use FileShare;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

sub ok
{
 	my ($num) = shift;
	my ($result) = shift;
	
	print "not " unless $result;
	print "ok $num\n";
}

## check the version number
ok 2, $Net::FileShare::VERSION eq '1.03';

## create object for testing...
my $object;

## we need a directory for testing the _directory option, so this is used
my $home_dir = `echo \$HOME`; chomp $home_dir;

## make a server object... 
eval '$object = Net::FileShare->new(
				_send_only => 1,
				_socket	   => 1,
				_directory => $home_dir,
				_debug	   => 1)';
ok 3, ref($object);

## test server_run_once
ok 4, eval '$object->server_run_once';


## test the DESTROY_SELF destructor
ok 5, eval '$object->DESTROY_SELF';

## check to see if object is still a reference to a Net::FileShare object
ok 6, ref($object) eq 'Net::FileShare';

## construct a client connection
eval '$object = Net::FileShare->new(
				_send_only => 0,
				_socket    => 1,
				_directory => $home_dir,
				_debug	   => 1)';

## check if it is still a reference
ok 7, ref($object);


