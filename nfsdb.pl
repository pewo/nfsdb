#!/usr/bin/perl -w

use strict;
use File::Find ();
use File::Path qw(make_path);
use File::Basename;
use Data::Dumper;
use English;
use Sys::Hostname;
use JSON; # imports encode_json, decode_json, to_json and from_json.

my($host) = hostname;
my($localtime) = scalar localtime(time);
my($maxpath) = 5;
sub maxpath($) {
	my($path) = shift;
	my(@arr) = split(/\//,$path);
	if ( $#arr >= $maxpath ) {
		$path = "";
		my($i) = $maxpath;
		while ( $i-- > 0 ) {
			$path .= "/" . shift(@arr);
		}
		#$path = join("/",$arr[0],$arr[1],$arr[2], $arr[3]);
		$path =~ s/^\/\//\//;
	}
	return($path);
}


my($comment) = "";
$comment .= "#\n";
$comment .= "# Created by $0 on $host\n";
$comment .= "# Timestamp $localtime\n";
$comment .= "#\n";


# Set the variable $File::Find::dont_use_nlink if you're using AFS,
# since AFS cheats.

# for the convenience of &wanted calls, including -eval statements:
use vars qw/*name *dir *prune/;
*name   = *File::Find::name;
*dir    = *File::Find::dir;
*prune  = *File::Find::prune;

my($file);
my($now) = time;
my(%res);
sub wanted {

	my($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = lstat($_);
	if ( /^\.snapshot\z/s ) {
		$File::Find::prune = 1;
		return;
	}

	return unless ( $mtime );
	#print "dir: " . $dir . " file: " . $name . "\n";
	my($maxpath) = maxpath($dir);
	$res{$maxpath}{size}+=$size;
	$res{$maxpath}{time}=time;
	$res{$maxpath}{files}++;
}

my($i) = 0;
my($subdir) = shift(@ARGV);
if ( $subdir ) {
	$i++ if ( -d $subdir );
}
die "Usage: $0 <directory>\n" unless ( $i ) ;

print $comment;

my($filename) = $subdir;
$filename =~ s/\W/_/g;
my($runtime) = time - $BASETIME;
sleep 1;
File::Find::find({wanted => \&wanted}, $subdir);

$i = 0;
my(%sum);
my($path);
foreach $path ( keys %res ) {
	#print "Dir: $path\n";
	my($dirpath) = "";
	foreach ( split(/\//,$path) ) {
		$dirpath .= "/$_";
		$dirpath =~ s/^\/*/\//;
		$sum{$dirpath}{size}+=$res{$path}{size};
		$sum{$dirpath}{files}+=$res{$path}{files};
		#$sum{$dirpath}{path}=$dirpath;
		my($shortpath) = $dirpath;
		$shortpath =~ s/^$subdir//;
		$sum{$dirpath}{path}=$shortpath;
		
	}
	#last if ( $i++ > 10 );
}

my($meta) = "";
$meta .= "%OUPUT=JSON\n";
$meta .= "%VERSION=1\n";
$meta .= "%TYPE=NFS\n";
$meta .= "%DIR=$subdir\n";
print $meta;

my($sumdir);
foreach $sumdir ( keys %sum ) {
	#print "sumdir=[$sumdir] subdir=$subdir\n";
	next unless ( $sumdir =~ /^$subdir/ );
	my($hp) = $sum{$sumdir};
	my($json) = encode_json $hp;
	print "$json\n";
}
#print Dumper(\%sum);



