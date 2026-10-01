#!/usr/bin/env perl
#  set-conf.pl
#  set and maintain the build's configuration variables
#  Copyright (C) 2026 Michael A. Demoulin
#  SPDX-License-Identifier: GPL-3.0-or-later
#
#  The settings live in lib/params, one "name = 0|1" per line.  It is plain
#  text so that a changed setting shows up in a diff, and so that it reads
#  the same on every system (a DBM file does not: its on-disk name and
#  format depend on which DBM library Perl was built with).  The build
#  depends on the file's timestamp, so only -s ever writes it; reading a
#  setting must never make every output look out of date.

use v5.36;
use English;

my  @settings = qw{
        expandabbrevs
        extra
        federal
        fancyacronyms
        fancyheaders
        fancyheadings
        twophones
        };
# what a fresh checkout starts with: the ordinary two-page industry resume
my  %defaults = (
        expandabbrevs => 0,
        extra         => 0,
        federal       => 0,
        fancyacronyms => 1,
        fancyheaders  => 1,
        fancyheadings => 0,
        twophones     => 0,
        );
my  $params = 'lib/params';
my  %config;

sub read_params () {
    %config = %defaults;
    open my $fh, '<', $params  or  return;
    while (my $line = <$fh>) {
        next if $line =~ /^\s*(#|$)/;
        my  ($name, $val) = $line =~ /^\s*(\w+)\s*=\s*([01])\s*$/
            or  die "$params: cannot parse: $line";
        $config{$name} = $val;
        }
    close $fh;
    }

sub format_vals () {
    # the one rendering of the settings, shared by -p and the file itself
    return join '', map { sprintf "%-13s = %s\n", $ARG, $config{$ARG} // 0 } @settings;
    }

sub write_params () {
    open my $fh, '>', $params  or  die "cannot write $params: $!\n";
    print {$fh} format_vals ();
    close $fh  or  die "cannot write $params: $!\n";
    }

sub setting ($param) {
    # output one boolean setting for the params.sty file
    print "\n\\newboolean{\@$param}\n";
    print "\\setboolean{\@$param}{", (($config{$param}) ? 'true' : 'false'), "}\n";
    }

sub generate_tex_config () {
    # output params.sty file
    print "% params.sty\n\n";
    print "\\usepackage{ifthen}\n";
    setting ($ARG) for @settings;
    }

sub eval_arg ($arg) {
    # evaluate one command-line argument, of the form 'foo=0'
    my  ($param, $val) = $arg =~ /^(\w+)=(.*)$/
        or  die "Bad argument: $arg (expected name=value)\n";
    die "Unknown setting: $param\n" unless grep { $ARG eq $param } @settings;
    $val = lc $val;
    $val = 1 if $val eq 'true' || $val eq 't';
    $val = 0 if $val eq 'false' || $val eq 'f' || $val eq 'nil';
    die "Bad value: $val\n" unless $val eq '0' || $val eq '1';
    $config{$param} = $val;
    }

sub show_val ($param) {
    # output one setting as a bare 0/1, for --stringparam
    die "Unknown setting: $param\n" unless grep { $ARG eq $param } @settings;
    print (($config{$param}) ? 1 : 0);
    }

sub usage () {
    print "set-conf.pl: set and maintain configuration variables\n";
    print "usage:\n";
    print "\tset-conf.pl -p\n";
    print "\t\tprint the values of the configuration variables\n";
    print "\tset-conf.pl -h\n";
    print "\t\tprint help screen\n";
    print "\tset-conf.pl -s <var>=<val> ...\n";
    print "\t\tset configuration variables (val: 0/1, t/f, true/false)\n";
    print "\t\tand write $params; with no <var>=<val>, write the defaults\n";
    print "\tset-conf.pl -v <var>\n";
    print "\t\tprint the bare value (0 or 1) of <var>, with no newline\n";
    print "\tset-conf.pl -t\n";
    print "\t\tprint configuration variables for LaTeX params.sty file\n";
    }

# ---------------------------------------------------------------
if (!@ARGV) {
    usage ();
    exit 1;
    }
read_params ();
my  $arg = shift @ARGV;
if    ($arg eq '-p') { print format_vals () }
elsif ($arg eq '-h') { usage () }
elsif ($arg eq '-v') { show_val (shift @ARGV // die "-v needs a variable name\n") }
elsif ($arg eq '-t') { generate_tex_config () }
elsif ($arg eq '-s') {
    eval_arg ($ARG) for @ARGV;
    write_params ();
    print format_vals ();
    }
else {
    usage ();
    exit 1;
    }
