#!/usr/bin/perl
use strict;
my $version="1.0";

# this script assumes everything is in the directory from which it was started:
#  - the script itself
#  - encoder.exe
#  - er-libisomedia.dll
#  - any .mp3/.amr/.awb files to be converted into playaway audio book
#
# ffmpeg, wine and mktemp must be path available
#


my @files=findFiles();
print "Playaway audio book creator $version\n\n";
if (@files==0){
    print "ERROR: No convertable files found in current directory.\n";
    exit 1;
}else{
    print "Found ".@files." convertable files.\n";
}

print "Please enter a bookname [max. 8 chars, letters and numbers only]: ";my $bookName=<>;chomp($bookName);
if((length($bookName)>8)||($bookName!~/[a-z0-9]{1,8}/i)){
    print STDERR "ERROR: Bookname must be 8 chars, letters and numbers only.\n";
    exit 2;
}
print "Please enter a bitrate [10...36]: ";my $bitRate=<>;chomp($bitRate);if($bitRate eq ""){$bitRate=10;};
if(($bitRate!~/[0-9]{2}/)||($bitRate>36)||($bitRate<10)){
    print STDERR "ERROR: Bitrate must be 10...36.\n";
    exit 2;
}
if(-d $bookName){
    print STDERR "ERROR: Directory $bookName already exists. Please delete first and restart this script.\n";
    exit 3;
}else{
    if(!mkdir($bookName)){
        print STDERR "ERROR: Could not create directory $bookName.\n";
        exit 4;
    }
}

my $cnt=0;
my @fileSizes=();
my $allFileSize=0;
foreach(@files){
    my $origFile=$_;
    $cnt++;
    print $origFile."\n";
    my $tempFile=`mktemp -u -p "."`;chomp($tempFile);$tempFile.".wav";
    my $back=system("ffmpeg -i \"$origFile\" -f wav -c:a pcm_s16le -ac 1 -ar 16000 -empty_hdlr_name 1 -fflags +bitexact -flags:v +bitexact -flags:a +bitexact -map_metadata -1 \"$tempFile\"");
    if($back==0){
	my $bookFile="$bookName/".sprintf("%04d", $cnt)." $bookName 0000.awb";
	$back=system("wine encoder.exe -rate $bitRate -mono -ff raw -if $tempFile -of \"$bookFile\"");
	unlink $tempFile;
	if($back!=0){
	    print STDERR "Could not convert temporary wav file to awb plus playaway file.\n";
	    exit 7;
	}
	my $fileSize = (stat $bookFile)[7];
	$allFileSize+=$fileSize;
	push @fileSizes,$fileSize;
    }else{
	print STDERR "Could not convert $origFile to temporary wav file.\n";
	exit 6;
    }
}
my $pre="AWBVOL082002SLD090080PUP003NMD".sprintf("%03d",$cnt)."BLN020BLP020ELA";
my $post="COP5521 \r\n";
my $mid="000";
my $sizeCnt=0;
my $mul=(0.95*$allFileSize/($bitRate*1024/8))/60;
foreach(@fileSizes){
    $sizeCnt+=$_;
    $mid.=sprintf("%03X",int(($mul*($sizeCnt)/$allFileSize)+1));
}

if(open(P,">$bookName/PATWEAKS.DAT")){
    print P $pre.$mid.$post;
    close(P);
}else{
    print STDERR "Could not create $bookName/PATWEAKS.DAT.\n";
    exit 8;
}

exit;

sub findFiles{
    my @file=();
    if(opendir(D,".")){
	foreach(readdir(D)){
	    my $entry=$_;
	    if(($entry ne ".")&&($entry ne "..")&&(($entry=~/\.mp3$/i)||($entry=~/\.amr$/i)||($entry=~/\.awb$/i))){
		push @files,$entry;
	    }
	}
	closedir(D);
	sort @files;
    }else{
	print STDERR "ERROR: Could not open directory . for reading.\n";
	exit 2;
    }
    return @files;
}
