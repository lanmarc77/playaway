#!/usr/bin/perl
use strict;
my $version="1.03";

# this script assumes everything is in the directory from which it was started:
#  - the script itself
#  - encoder.exe
#  - er-libisomedia.dll
#  - any .mp3/.amr/.awb files to be converted into Playaway audio book
#
# ffmpeg, wine and mktemp must be path available
#
# Version history
# V1.03   : added option to choose to generate files for Playaway light or classic, cosmetics and more error checking
# V1.02   : fixed sorting error, allow direct conversion of wav assuming they have a fitting format
# V1.01   : changes in COP field and ffmpeg parameters
# V1.0    : inital version


my @files=findFiles();
print "Playaway audio book creator $version\n\n";
if (@files==0){
    print "ERROR: No convertable files found in current directory.\n";
    exit 1;
}else{
    print "Found ".@files." convertable files.\n";
}

print "Please enter a bookname (max. 8 chars, letters and numbers only): ";my $bookName=<>;chomp($bookName);
if((length($bookName)>8)||($bookName!~/[a-z0-9]{1,8}/i)){
    print STDERR "ERROR: Bookname must be 8 chars, letters and numbers only.\n";
    exit 2;
}
print "Please enter a bitrate 10...36 [10]: ";my $bitRate=<>;chomp($bitRate);if($bitRate eq ""){$bitRate=10;};
if(($bitRate!~/[0-9]{2}/)||($bitRate>36)||($bitRate<10)){
    print STDERR "ERROR: Bitrate must be 10...36.\n";
    exit 2;
}
print "Generate for Playway model light or classic? [c]/l: ";my $model=<>;chomp($model);if($model eq ""){$model="c";};
if(($model ne "c")&&($model ne "l")){
    print STDERR "ERROR: Model selection must eihter be c or l.\n";
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
    print "Working on file: ".$origFile." ($cnt/".@files.")\n";
    my $back=-1;
    my $tempFile="";
    if($origFile!~/\.wav$/){
	$tempFile=`mktemp -u -p "."`;chomp($tempFile);$tempFile.".wav";
	$back=system("ffmpeg -hide_banner -v error -stats -i \"$origFile\" -f wav -c:a pcm_s16le -ar 44100 -empty_hdlr_name 1 -fflags +bitexact -flags:v +bitexact -flags:a +bitexact -map_metadata -1 \"$tempFile\"");
    }else{
	$tempFile=$origFile;
	$back=0;
    }
    if($back==0){
	my $bookFile="$bookName/".sprintf("%04d", $cnt)." $bookName 0000.awb";
	my $tempSize = (stat $tempFile)[7];
	if($tempSize >= 2*1024*1024*1024){
	    print STDERR "ERROR: The converted/supplied .wav is greater than 2GiB (usually files runtime > 3h:22min:45s). The encoder.exe is 32bit and can not handle files this size.\n";
	    if($origFile ne $tempFile){
		unlink $tempFile;
	    }
	    exit 7;
	}
	$back=system("wine encoder.exe -rate $bitRate -mono -ff raw -if \"$tempFile\" -of \"$bookFile\"");
	if($origFile ne $tempFile){
	    unlink $tempFile;
	}
	if($back!=0){
	    print STDERR "ERROR: Could not convert temporary wav file to awb plus Playaway file.\n";
	    exit 7;
	}
	my $fileSize = (stat $bookFile)[7];
	$allFileSize+=$fileSize;
	push @fileSizes,$fileSize;
    }else{
	print STDERR "ERROR: Could not convert $origFile to temporary wav file.\n";
	exit 6;
    }
}
my $preAllModels="AWBVOL082002SLD090080PUP003NMD";
my $preLight=$preAllModels.sprintf("%03d",$cnt)."BLN020BLP020ELA";
my $preClassic=$preAllModels.sprintf("%03d",$cnt);
my $post="COP0000\r\n";
my $mid="000";
my $sizeCnt=0;
my $mul=(0.95*$allFileSize/($bitRate*1024/8))/60;
foreach(@fileSizes){
    $sizeCnt+=$_;
    $mid.=sprintf("%03X",int(($mul*($sizeCnt)/$allFileSize)+1));
}

if(open(P,">$bookName/PATWEAKS.DAT")){
    if($model eq "c"){
	$mid="";
	$post="\r\n";
	print P $preClassic.$mid.$post;
    }else{
	print P $preLight.$mid.$post;
    }
    close(P);
}else{
    print STDERR "ERROR: Could not create $bookName/PATWEAKS.DAT.\n";
    exit 8;
}

exit;

sub findFiles{
    my @file=();
    if(opendir(D,".")){
	foreach(readdir(D)){
	    my $entry=$_;
	    if(($entry ne ".")&&($entry ne "..")&&(($entry=~/\.mp3$/i)||($entry=~/\.amr$/i)||($entry=~/\.awb$/i)||($entry=~/\.wav$/i))){
		push @files,$entry;
	    }
	}
	closedir(D);
	@files=sort @files;
    }else{
	print STDERR "ERROR: Could not open directory . for reading.\n";
	exit 2;
    }
    return @files;
}
