#!/usr/bin/perl -w
#
# Net::FileShare.pm 		1-07-03
# Gene Gallistel 		<gravalo@uwm.edu>
# copyright (c) 1-07-03
#
package Net::FileShare;
use IO::Socket::INET;
use Carp;
use strict;
use vars qw($VERSION);
$VERSION = '1.03';

use vars qw( @ISA @EXPORT );
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw( );

 ## The following is a very basic group of packets. 
 ## These will be used to send and receive commands
 ## between the client and server.
 use vars qw( $M_QUERY $M_ACK $M_REJ );
 $M_QUERY	=	'b';	# query packet
 $M_ACK		=	'c';	# acknowledgement packet
 $M_REJ		=	'd';	# opposite of $M_ACK. 
 ## if $M_REJ is sent to client, it means immediate disconnect. The
 ## server will not respond to an $M_REJ packet from a client.

 ## The following is the hash containing constructor elements. 
 ## _send_only - on(1)/off(0) switch, which may seem redundant, since one would 
 ## have to choose either server_connection or client_connection, but I perfer
 ## to err on the side of safety. 
 ## _socket - _socket will be an IO::Socket::INET object. Assign a scalar to it. 
 ## I had serious problems with this, setting up this solution for it.
 ## _directory - dual purpose, for server, the directory which the shared
 ## files will be stored. For the client, the download directory.
 ## _debug - on(1)/off(0) switch. If on, will print debugging information. 
 my (%_fields) = ( _send_only => '???', _socket => '???', _directory => '???',
		   _debug => '???');
		

my (@_files);			# array for files read from directory
my ($files_ref) = \@_files;	# reference to point to @_files
my ($directory);

	# constructor for object creation
	sub new
	{
		my ($class, %args) = @_;
		my ($self) = {%_fields};

		foreach my $field (keys %_fields)
		{
			$self->{$field} = $args{$field}
				if defined $args{$field};
		}
		bless $self, $class;
		
		## assign _directory to the global. This
		## will be used in the read_directory sub. 
		$directory = $self->{_directory};
	   return $self;
	}

	## sub for checking version
	sub version { $VERSION; }

	# standard destructor 
	## Will print the nice little message below, then sleep for
	## one second, undefine self and exit. 
	sub DESTROY_SELF
	{
		my ($self) = shift;
		undef %$self;
		sleep 1;
		croak "\nSELF has been DESTROYED...\n";
	}

	sub client_connection
	{
		my ($self, $server, $port, $file) = ($_[0], $_[1], $_[2], $_[3] || " ");
		my ($file_size, $bytes_read, $data) = 0;

		## client must send _send_only to 0, or false	
		if ($self->{_send_only} ne "0") {
			croak "\nClient must set _send_only option to 0";
		}

		my ($socket) = IO::Socket::INET->new(
						PeerAddr => $server,
						PeerPort => $port,
						Proto    => "tcp",
						Type	 => SOCK_STREAM)
				or croak "Cannot establish socket connection: $!";

		# save socket for later use	
		$self->{_socket} = $socket;
	
		## if socket is not defined, there is no point in continuing on   
		if(not defined($socket)) {
			croak "\nSocket is not defined in client_connection";
		}

		## check to confirm file name is not blank
		if ($file eq " ") {
			croak "\nFile to download is not specified in client_connection.";
		}
	
		## sending query and file name to the server
		$self->send_cmd($M_QUERY, $file);

		## declare the variables for listening to the server 
		## and receiving a packet and filename from the server.		
		my ($type, $response);
		($type, $response) = $self->recv_cmd;
		 
		## first check to confrim packet from server was not a $M_REJ
		if ($type eq $M_REJ) {		  
 			croak "\nReceived a rejection packet from server";
		} elsif ($type eq $M_ACK) {
		## If type is equal to M_ACK, a file size should follow.
		## After that, the client should open a new file, and 
		## print until file size has been reached...something 		
		## like that
			$file_size = $response;
			open (OUTFILE, ">$directory/$file.copy") or croak "Cannot open file for writing: $!";
			
			while (read($socket, $data, $file_size)) {
				print OUTFILE $data;
				$bytes_read += length($data);

					## When bytes read is equal to the file's size
					## end the read/print loop 
					if ($bytes_read eq $file_size) {
						last;
					}
			}
			close (OUTFILE) or croak "Cannot close file: $!";
			
			## if everything goes well, up to this point, 
			## file has been downloaded and is now closed.
			print STDERR "\nDownloaded $file from server and saved it as, $file.copy.\n";
			sleep 1; ## sleep for one second
			exit 0;  ## exit  
		} else {
			## server will never send a $M_QUERY packet,
			## so if not the first two, there must be a 
			## problem.
			croak "\nUndetermined packet from server";
		} 
	   #return;
	}

	## Impliments a server connection 
	sub server_connection
	{
		my ($self, $port) = ($_[0], $_[1] || "3000");
		my ($filename) = " ";
		my ($type, $file_size, $number_of_files);
		my ($remote, $hostinfo);
		my ($data, $buffersize) = 1024;
			
		## This may seem realy redundant, but if someone can 
		## set up a file server in under 10 lines of code with 
		## this .pm they should be able to specify the option '1'
		## for _send_only 
		if ( $self->{_send_only} ne "1" ) {
			croak "Server dying...variable _send_only must be set to 1"; 
		}
	
		# create new socket
		my ($socket) = new IO::Socket::INET(
						Listen	  => 10, #could also be SOMAXCONN
						LocalPort => $port,
						Reuse	  => 1,
						Proto	  => 'tcp')
				or croak "Could not open socket for listening: $!";
		
		## read_directory sub returns an array of files in directory
		@{$files_ref} = read_directory();	

		## used for printing out the files in the $self->{_directory} directory  
		$number_of_files = @{$files_ref};
	
		## print the contents of $self->{_directory} to STDERR, 
		## so they can be scene while server is engaged.
		if ($self->{_debug} eq "1") {
			print STDERR "Files to offer: \n";
			for (my $i = 0; $i < $number_of_files; ++$i){
				print STDERR $files_ref->[$i];
				print STDERR "\n";
			}	
		}

		while (defined ($remote = $socket->accept)) {	
			#$remote->autoflush(1);
			$hostinfo = gethostbyaddr($remote->peeraddr, AF_INET);
			
			## This was a pain to figure out. Save the
			## socket for later. It's changed for because 
			## of the $socket->accept
			$self->{_socket} = $remote;

			## Listen for the client to send an $M_QUERY packet 
			## and a filename.
			($type, $filename) = $self->recv_cmd();

			## if packet is not $M_QUERY packet (ie. $M_ACK or
			## $M_REJ packet) send a $M_REJ packet to the client.
			## Then skip to the next iteration of the while loop.
			if ($type ne $M_QUERY) {
				## at this point, an incorrect message has been 
				## sent to the server. The servers response is a 
 				## rejection packet. If the client isn't listening,
 				## this could cause an error, so 'next' no matter what.	
				if (eval { $self->send_cmd($M_REJ) } ) {
					next;
				} else {
					next;
				}
			}			

			## If client sends a $M_QUERY packet, determine if file
			## exists in $directory and is readable. If not, send 
			## a response to client.
			## Then skip to the next iteration of the while loop.
			if ((-e "$directory/$filename") && (-r "$directory/$filename")) {
			
				print STDERR "File $filename exists and is readable\n" if ($self->{_debug} eq "1");

				## Determine the size of the specified file.
				$file_size = (stat("$directory/$filename"))[7];
	
				## Send a $M_ACK packet and a file size	
				$self->send_cmd($M_ACK, "$file_size");

				open (INPUT, "<$directory/$filename") or croak "Cannot open input file $filename: $!";
					while (read(INPUT, $data, $file_size)) {
						print $remote $data;
					}
				print STDERR "File transfer complete\n" if ($self->{_debug} eq "1");
				close (INPUT) or croak "Cannot close input file $filename: $!";
			} else {
				## the instance, where the file does not exist or is not readable
				if (eval { $self->send_cmd($M_REJ) }) {
					next;
				} else {
					next;
				}
			}
		  next;
		}
		
	}

	## this is only a testing instance of the server. As the
	## sub name states, server will be created, bound to a socket
	## and then disconnect. 
	sub server_run_once
	{
	my ($self, $port) = ($_[0], $_[1] || "3000");
	my ($remote, $hostinfo);
	croak "_send_only must be set to 1 for server\n" if ($self->{_send_only} ne "1");
	
	my ($socket) = new IO::Socket::INET(
			Listen 		=> 1,
			LocalPort 	=> $port,
			ReUse		=> 1,
			Proto		=> 'tcp')
		or croak "Cannot bind socket\n";

		croak "server_run_once has completed its run\n";
	}

	## Read the list of files into the @_files array for later use.
	## The only use for this is for debugging purposes.
	sub read_directory
	{
		my ($self) = $_[0];
	 	my ($dir) = $_[1] || $directory;
		my ($file);
		opendir(DIR, $dir) or croak "Cannot open directory: $dir : $!";
			while (defined ($file = readdir (DIR))) {
				## include a check to find '.' directorys
				## and jump the the next element
				push(@_files, $file);
			}
		closedir(DIR);
		return @_files;
	}

	## Send a packet over the wire. This should not
	## be used by clients/servers directly, but only
	## by the send_cmd() sub.  
	sub _send_packet {
		my ($self, $packet) = @_;
		my ($socket) = $self->{_socket};
		my ($plen) = length($packet);	# Size plus null.

		# Bounds checking to MAXCHAR-1 (terminating null).
		if ($plen > 254) {
			croak "send: packet > 255 bytes";
		}

		# Add the terminating null.
		$packet .= "\0"; $plen++;

		# Add the packet length (<= 255) to the packet head.
		$packet = chr($plen).$packet; $plen++;

		my $wrotelen = send($socket, $packet, 0);
		if (not defined($wrotelen)) {
			croak "send: $!";
		} elsif ($wrotelen != $plen) {
			croak "send: wrote $wrotelen of $plen: $!";
		} else {
			return 'ok';
		}
		return;
	}

	## Read a pending packet from the socket. This should
	## not be used directly by either clients/servers, but 
	## only by the recv_cmd() sub. 
	sub _recv_packet {
		my ($self) = @_;
		my ($socket) = $self->{_socket};
		my ($slen, $buffer, $ret);

		# Read a byte of packet length.
		$ret = recv($socket, $slen, 1, 0);
		if (not defined($ret)) {
			croak "recv size: $!";
		} elsif (length($slen) != 1) {
			croak "recv size != 1: $!";
		} else {
			# Convert char to integer.
			$slen = ord($slen);
			
			## cough...hickup...
			## in case someone tries to overwrite the nice
			## 255 byte buffer, it will be cut down to 25
			## and read in...
			if ($slen > 255) { $slen = 25; }

			while ($slen) {	# Read the entire packet.
				my $pbuf;
				$ret = recv($socket, $pbuf, $slen, 0);
				if (not defined($ret)) {
					croak "recv msg: $!";
				} else {
					$slen -= length($pbuf);
					$buffer .= $pbuf;
				}
			}
		
			# Remove trailing null.
			chop($buffer);
			return($buffer);
		}
		return;
	}
	
	# Read a message from the server and break it into its fields.
	sub recv_cmd {
		my ($self) = shift;
		my ($msg);

		# Read the waiting packet.
		if (eval { $msg = $self->_recv_packet() }) {
			# Break up the message.
			my ($type, $buf) = split(/,/, $msg);

			## if debugging set, print packet type and buffer
			if ($self->{_debug} eq "1") {
				print STDERR "\nReceiving Packet Type: $type\nReceiving Buffer: $buf\n";	
			}

			if (($self->{_send_only} eq "0") && ($type eq $M_REJ)) {
				croak "Received rejection packet from server";
			}
			
			return ($type, $buf);
		}
	
	  return;
	}

	sub send_cmd 
	{
		if (@_ > 2) {
			my ($self, $cmd, $data) = @_;

			## $cmd will be either $M_QUERY, $M_ACK, or $M_REJ
			## The first two will have a second scalar with them.
			## $M_REJ is the equivalent of a kill packet to client. 
			## Server will not respond to the $M_REJ packet.
			
			## printing options if debugging option set
			if ($self->{_debug} eq "1") {
				print STDERR "\nSending Command: $cmd\nSending Data: $data\n";
			}
			
			my ($buf) = "$cmd,$data";

			if (eval { $self->_send_packet($buf) }) {
				return 'ok';
			}
		} else {
			my ($self, $cmd) = @_;
			my ($buf) = "$cmd,";
			
			## again, printing $cmd if debugging is set to 1
			if ($self->{_debug} eq "1") {
				print STDERR "\nSending Command: $cmd\n";
			}			

			if (eval { $self->_send_packet($buf) }) {
				return 'ok';
			}

		}
	}	

1;
__END__

=head1 NAME

Net::FileShare - Object oriented interface for the creation of file sharing clients and servers

=head1 SYNOPSIS
	## the following is the source for constructing a file sharing server, using C<Net::FileShare>
	#!/usr/bin/perl -w
	use strict;
	use Net::FileShare;
	my ($fh) = Net::FileShare->new(
			_send_only => 1,
			_socket    => 1,
		 	_directory => '/path/to/files/to/serve',
		 	_debug     => 1);
  	$fh->server_connection;

	## the following is the complimentary client constructed with the module
	#!/usr/bin/perl -w
	use strict;
	use Net::FileShare;

	my ($fh) = Net::FileShare->new(
			_send_only => 0,
			_socket    => 1,
			_directory => '/home/usr_id',
			_debug     => 1);
  	$fh->client_connection("x.x.x.x", "port", "some_file");


=head1 DESCRIPTION

C<Net::FileShare> provides an object interface for creating file sharing clients and servers. This project started while I was developing an ICB bot. I wanted a simple interface to allow people to share files. My original thought was that this should be developed into a module to allow individuals to easily integrate file sharing functionality into chatter bots or chat clients. Thus began the development of C<Net::FileShare>. 

C<Net::FileShare> uses a very basic ascii based protocol for communication between servers and clients. Clients and servers developed with C<Net::FileShare> will only function with other clients/servers developed with this module. 

Only four options can be passed to the object you're creating. They are: _send_only, _socket, _directory, and _debug._send_only and _debug function similiar to bool variables. They use a 1/0 (on/off) mechanism. _send_only must be set for both clients and servers. This may seem very redundant, but I perfer to err on the side of security. _socket needs to be set to a scalar as it will become a ref to a socket object created with C<IO::Socket::INET>. _directory holds the dir path of where to look for files to serve, for the server, and where to files for the client. 

After setting the previously mentioned four options, then execute the server_connection() sub or the client_connection() sub. The server_connection sub will take only one option, which is the port to bind to, if other than 3000. The client_connection() sub takes three options. These are the host(ie. IP x.x.x.x), port (3000 - by default) and file to request.  

=head1 AUTHOR

Gene Gallistel, gravalo@uwm.edu

=cut
