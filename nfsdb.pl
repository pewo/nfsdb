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
my($maxdepth) = 2;
sub maxpath($) {
	my($path) = shift;
	my(@arr) = split(/\//,$path);
	my($depth) = $#arr;
	#print "path=[$path], depth=[$depth]\n";
	if ( $#arr >= $maxdepth ) {
		$path = "";
		my($i) = $maxdepth;
		while ( $i-- > 0 ) {
			$path .= "/" . shift(@arr);
		}
		$path =~ s/^\/\//\//;
	}
	return($path,$depth);
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
	# Do not enter .snapshot
	if ( /^\.snapshot\z/s ) {
		$File::Find::prune = 1;
		return;
	}

	# Keep us inside starting filesystem
	if ( $dev != $File::Find::topdev ) {
		$File::Find::prune = 1;
		return;
	}

	return unless ( -f $_ );

	return unless ( $mtime );
	my($maxpath,$depth) = maxpath($dir);
	#print "dir: " . $dir . " file: " . $name . " maxpath: $maxpath, depth=$depth\n";
	$res{$maxpath}{size}+=$size;
	$res{$maxpath}{time}=time;
	$res{$maxpath}{files}++;
}

my($subdir) = shift(@ARGV);
if ( $subdir ) {
	#print "Subdir=[$subdir]\n";
	$subdir = dirname($subdir) . "/" . basename($subdir);
	#print "Subdir=[$subdir]\n";
}
die "Usage: $0 <directory>\n" unless ( -d $subdir ) ;

# Calculate maxdepth based on depth on searchdir + $maxdepth (1)
my($dummy,$depth) = maxpath($subdir);
$maxdepth += $depth;

print $comment;

my(%meta) = (
	HEADER => 1,
	OUTPUT => "json",
	VERSION => 1,
	TYPE => "nfs",
	DIR => $subdir,
	EPOC => time,
	MAXDEPTH => $maxdepth,
);
print encode_json(\%meta) . "\n";

my($filename) = $subdir;
$filename =~ s/\W/_/g;
my($runtime) = time - $BASETIME;
sleep 1;
File::Find::find({wanted => \&wanted}, $subdir);

my($i) = 0;
my(%sum);
my($path);
#print Dumper(\%res);
foreach $path ( keys %res ) {
	#print "Dir: $path\n";
	my($dirpath) = "";
	foreach ( split(/\//,$path) ) {
		$dirpath .= "/$_";
		$dirpath =~ s/^\/*/\//;
		$sum{$dirpath}{size}+=$res{$path}{size};
		$sum{$dirpath}{files}+=$res{$path}{files};
		my($shortpath) = $dirpath;
		$shortpath =~ s/^$subdir//;
		$sum{$dirpath}{path}=$shortpath;
		#$sum{$dirpath}{path}=$dirpath;
		
	}
	#last if ( $i++ > 10 );
}

#print Dumper(\%sum);

my($sumdir);
foreach $sumdir ( keys %sum ) {
	#print "sumdir=[$sumdir] subdir=$subdir\n";
	unless ( $sumdir =~ /^$subdir/ ) {
		#print "Skipping [$sumdir] it is not inside [$subdir]\n";
		next;
	}
	my($hp) = $sum{$sumdir};
	my(@arr) = ();
	push(@arr,"path",$hp->{path});
	delete($hp->{path});
	foreach ( sort keys %$hp ) {
		#print "Key=$_, value=$hp->{$_}\n";
		push(@arr,$_,$hp->{$_});
	}
	#my($json) = encode_json $hp;
	my($json) = encode_json \@arr;
	print "$json\n";
}
#print Dumper(\%sum);
