#!/usr/bin/env perl
# cifsiostat.pl SNMP parser
#
# Based heavily on the awesome iostat-persist.pl by Mark Round
#
# NOTE: the .1.3.6.1.3.2 OID in this script is hopefully as exprimental and
# unique as the one in iostat.pl.
#
# USAGE
# -----
# See the README which should have been included with this file.
#
# CHANGES
# -------
# 15/04/2018 - Version 0.1 - Brutal hack of iostat-persist.pl to adopt it to
#                            cifsiostat. /@njesper
#
# Copyright 2009 Mark Round and others. All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without modification, 
# are permitted provided that the following conditions are met:
# 
#  1. Redistributions of source code must retain the above copyright notice, 
#     this list of conditions and the following disclaimer.
#  2. Redistributions in binary form must reproduce the above copyright notice, 
#     this list of conditions and the following disclaimer in the documentation 
#     and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, 
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND 
# FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHORS 
# OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, 
# OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE 
# GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR 
# TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS 
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

use strict;

use constant debug => 0;
my $base_oid = ".1.3.6.1.3.2";
my $iostat_cache = "/tmp/cifsiostat.cache";
my $req;
my %stats;
my $devices;
my $mibtime;

# Results from iostat are cached for some seconds so that an
# SNMP walk doesn't result in collecting data over and over again:
my $cache_secs = 15;

# Switch on autoflush
$| = 1;

while (my $cmd = <STDIN>) {
  chomp $cmd;

  if ($cmd eq "PING") {
    print "PONG\n";
  } elsif ($cmd eq "get") {
    my $oid_in = <STDIN>;
    chomp $oid_in;
    process();
    getoid($oid_in);
  } elsif ($cmd eq "getnext") {
    my $oid_in = <STDIN>;
    chomp $oid_in;
    process();
    my $found = 0;
    my $next = getnextoid($oid_in);
    getoid($next);
  } else {
    # Unknown command
  }
}

exit 0;

sub process {

    # We cache the results for $cache_secs seconds
    if (time - $mibtime < $cache_secs) {
      return 'Cached';
    }

    $devices = 1;
    open( IOSTAT, $iostat_cache )
      or return ("Could not open iostat cache $iostat_cache : $!");

    my $header_seen = 0;

    while (<IOSTAT>) {
        if (/^[F|f]ilesystem/) {
            $header_seen++;
            next;
        }
        next if ( $header_seen < 2 );
        next if (/^$/);
        
        /^([a-zA-Z0-9\-\/]+)\s+(\d+[\.,]\d+)\s+(\d+[\.,]\d+)\s+(\d+[\.,]\d+)\s+(\d+[\.,]\d+)\s+(\d+[\.,]\d+)\s+(\d+[\.,]\d+)\s+(\d+[\.,]\d+)/;

        $stats{"$base_oid.1.$devices"}  = $devices;	# index
        $stats{"$base_oid.2.$devices"}  = $1;		# Filesystem
        $stats{"$base_oid.3.$devices"}  = $2;		# rkB/s
        $stats{"$base_oid.4.$devices"}  = $3;		# wkB/s
        $stats{"$base_oid.5.$devices"}  = $4;		# rops/s
        $stats{"$base_oid.6.$devices"}  = $5;		# wops/s
        $stats{"$base_oid.7.$devices"}  = $6;		# fo/s
        $stats{"$base_oid.8.$devices"}  = $7;		# fc/s
        $stats{"$base_oid.9.$devices"}  = $8;		# fd/s

        $devices++;
    }

    $mibtime = time;
}

sub getoid {
    my $oid = shift(@_);
    print "Fetching oid : $oid\n" if (debug);
    if ( $oid =~ /^$base_oid\.(\d+)\.(\d+).*/ && exists( $stats{$oid} ) ) {
        print $oid. "\n";
        if ( $1 == 1 ) {
            print "integer\n";
        }
        else {
            print "string\n";
        }
        print $stats{$oid} . "\n";
    } else {
      print "NONE\n";
    }
}

sub getnextoid {
    my $first_oid = shift(@_);
    my $next_oid  = '';
    my $count_id;
    my $index;

    if ( $first_oid =~ /$base_oid\.(\d+)\.(\d+).*/ ) {
        print("getnextoid($first_oid): index: $2, count_id: $1\n") if (debug);
        if ( $2 + 1 >= $devices ) {
            $count_id = $1 + 1;
            $index    = 1;
        }
        else {
            $index    = $2 + 1;
            $count_id = $1;
        }
        print(
            "getnextoid($first_oid): NEW - index: $index, count_id: $count_id\n"
        ) if (debug);
        $next_oid = "$base_oid.$count_id.$index";
    }
    elsif ( $first_oid =~ /$base_oid\.(\d+).*/ ) {
        $next_oid = "$base_oid.$1.1";
    }
    elsif ( $first_oid eq $base_oid ) {
        $next_oid = "$base_oid.1.1";
    }
    else {
        $next_oid = "$base_oid.1.1";
    }
    print("getnextoid($first_oid): returning $next_oid\n") if (debug);
    return $next_oid;
}
