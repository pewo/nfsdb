#!/usr/bin/perl -w

use strict;
use File::Find ();
use File::Path qw(make_path);
use English;

# Set the variable $File::Find::dont_use_nlink if you're using AFS,
# since AFS cheats.

# for the convenience of &wanted calls, including -eval statements:
use vars qw/*name *dir *prune/;
*name   = *File::Find::name;
*dir    = *File::Find::dir;
*prune  = *File::Find::prune;

my($file);
my($age) = undef;
my($diff) = undef;
my($now) = time;
my($outputbase) = "/var/tmp/findnew";

sub wanted {

	my($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = lstat($_);
	return unless ( $mtime );

	$now = time;
	if ( -f _ && $mtime > $age ) {
		$file = $name;
		$age = $mtime;
		$diff = $now - $age ;
		print "File: $file, age: $age, diff: $diff, localtime: " . localtime($age) . "\n";
	}
}

if ( ! -d $outputbase ) {
	make_path($outputbase, { verbose => 1, mode => 0700, });
}
if ( ! -d $outputbase ) {
	chdir($outputbase);
	die "chdir($outputbase): $!\n";
}
	
my($dir);
my($i) = 0;
my(@dirs) = ();
foreach $dir ( @ARGV ) {
	next unless ( $dir );
	next unless ( -d $dir );
	push(@dirs,$dir);
}

foreach $dir ( @dirs ) {
	my($filename) = $dir;
	$filename =~ s/\W/_/g;
	$filename = $outputbase . "/findnew" . $filename . ".log";
	my($runtime) = time - $BASETIME;
	print "\n*** $i/$#dirs logfile for directory $dir is $filename (Runtime is $runtime seconds) ***\n";
	sleep 1;
	$age = 0;
	File::Find::find({wanted => \&wanted}, $dir);

	unlink($filename);
	unless ( open(LOG,">$filename") ) {
		die "Cant write to $filename: $!\n";
	}

	my($days) = time - $age;
	$days = $days / ( 60 * 60 * 24 );

	print LOG sprintf("%s Days %d\tLocaltime %s\tRuntime %s\tFile %s (%s)\n",$age, $days, scalar localtime($age), $runtime, $file,$dir);
	close(LOG);
	
	$i++;
}

die "Usage: $0 <directory>\n" unless ( $i ) ;


