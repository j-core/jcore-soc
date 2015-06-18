#!/usr/bin/perl

use strict;
use warnings;

sub read_rambank
{
    my $rambank = shift || return;
    my $datfile = shift || return;

    my @O = qx| awk '{if(\$2 ~ /$rambank/){print \$3 " " \$5;}}' "$datfile" |;
    $_ =~ s/\n//g for @O;
    $_ =~ s/\r//g for @O;
    $_ =~ s/;$//g for @O;

    my @OO = map { my($a, $b) = split / /=> $_; "$a => x\"$b\"," } @O;
    return join "\n" => @OO;
}

open(my $VHDL_IN, "< memory_fpga.vhd.in") or
	die "Cannot open memory_fpga.vhd.in for reading: $!\n";

my $c1 = -1;
my $tag = undef;
my $lineno = 0;
my $datfile = $ARGV[0] || "testrom/ram.dat";

while(! eof($VHDL_IN)) {
    chomp(my $line = <$VHDL_IN>); $lineno++;
    my $ll = $line;
    $ll =~ s/^\s+//g; # ltrim
    my @TAGS = split /\s+/ => $ll;
    
    print $line, "\n";

    if(@TAGS && defined $TAGS[0] && $TAGS[0] =~ /RAM[0-9][HL][HL]/) {
      $c1 = $lineno; $tag = $TAGS[0];
      next;
    }
    if($line =~ /generic map/ && $lineno == ($c1 + 1)) {
      print "-- $tag INSERTED\n";
      print read_rambank($tag, $datfile), "\n";;
      $c1 = -1; $tag = undef;
    }
}
close($VHDL_IN);
