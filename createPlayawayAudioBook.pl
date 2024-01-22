#!/usr/bin/perl
use strict;
my $version="1.05";

# this script assumes everything is in the directory from which it was started:
#  - the script itself
#  - encoder-new binary precompiled from https://github.com/lanmarc77/amr-wbp-plus/releases in local directory
#  - any .mp3/.amr/.awb/.m4a/.ogg files to be converted into Playaway audio book
#
# ffmpeg, ffprobe and mktemp must be path available
#
# Version history
# V1.05   : added auto bitrate selection based on flash storage of device and runtime of files, added file split mode
# V1.04   : updated for faster none wine encoder, thanks to Dhiru Kohlia https://github.com/kholia/amr-wbp-plus
# V1.03   : added option to choose to generate files for Playaway light or classic, cosmetics and more error checking
# V1.02   : fixed sorting error, allow direct conversion of wav assuming they have a fitting format
# V1.01   : changes in COP field and ffmpeg parameters
# V1.0    : initial version

print "Playaway audio book creator $version\n\n";
my @flashSizes=("105000","229000","469000");#size of usable 1k blocks
preFlightChecks();
print "Reading file list";
my @files=();
my $sumRuntime;
findFiles(\@files,\$sumRuntime);
print "\n";
if (@files==0){
    print "ERROR: No convertable files found in current directory.\n";
    exit 1;
}else{
    print "Found ".@files." convertable files with runtime of $sumRuntime seconds (".int($sumRuntime/3600)."h:".int(($sumRuntime%3600)/60)."m).\n";
}

print "Please enter a bookname (max. 8 chars, letters and numbers only): ";my $bookName=<>;chomp($bookName);
if((length($bookName)>8)||($bookName!~/[a-z0-9]{1,8}/i)){
    print STDERR "ERROR: Bookname must be 8 chars, letters and numbers only.\n";
    exit 2;
}
print "Please enter a bitrate 10...36 or a1,a2,a4 [a1] (a=automatic,1=1Gbit flash): ";my $bitRate=<>;lc(chomp($bitRate));if($bitRate eq ""){$bitRate="a1";};
if($bitRate=~/^a\d$/){
    if($bitRate eq "a1"){
        $bitRate=int((@flashSizes[0]*8/$sumRuntime));
    }elsif($bitRate eq "a2"){
        $bitRate=int((@flashSizes[1]*8/$sumRuntime));
    }elsif($bitRate eq "a4"){
        $bitRate=int((@flashSizes[2]*8/$sumRuntime));
    }else{
        print STDERR "ERROR: Only a1,a2,a4 are supported.\n";
        exit 2;
    }
    if($bitRate>36){
        $bitRate=36;
    }
    if($bitRate<10){
        print STDERR "ERROR: The files do not fit completely on that flash.\n";
        exit 2;
    }
    print "Using automatic determined bitrate: $bitRate\n";
}else{
    if(($bitRate!~/[0-9]{2}/)||($bitRate>36)||($bitRate<10)){
        print STDERR "ERROR: Bitrate must be 10...36.\n";
        exit 2;
    }
}
print "Splitmode for files? ([n],5...60): ";my $splitMode=<>;chomp($splitMode);if($splitMode eq ""){$splitMode="n";};
if($splitMode ne "n"){
    if(($splitMode!~/^\d+$/)||($splitMode < 5)||($splitMode > 60)){
         print STDERR "Only values between 5...60 are allowed.\n";
    }
}
print "Generate for Playway model classic or light? [c]/l: ";my $model=<>;chomp($model);if($model eq ""){$model="c";};
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

my $origFileCnt=0;
my @convertedFileRuntimes=();
foreach(@files){
    my $origFile=$_;
    $origFileCnt++;
    my $endFlag=0;
    my $currentPartStart=0;
    do{
        print "Working on file: ".$origFile." ($origFileCnt/".@files.")\n";
        my $back=-1;
        my $tempFile="";
        if($origFile!~/\.wav$/){
            $tempFile=`mktemp -u -p "."`;chomp($tempFile);$tempFile.".wav";
            if($splitMode eq "n"){
                $back=system("ffmpeg -hide_banner -v error -stats -i \"$origFile\" -f wav -c:a pcm_s16le -ar 44100 -ac 1 -empty_hdlr_name 1 -fflags +bitexact -flags:v +bitexact -flags:a +bitexact -map_metadata -1 \"$tempFile\"");
                $endFlag=1;
            }else{
                print "Current timecode ".$currentPartStart."min\n";
                $back=system("ffmpeg -hide_banner -v error -stats -ss ".($currentPartStart*60)." -t ".($splitMode*60)." -i \"$origFile\" -f wav -c:a pcm_s16le -ar 44100 -ac 1 -empty_hdlr_name 1 -fflags +bitexact -flags:v +bitexact -flags:a +bitexact -map_metadata -1 \"$tempFile\"");
                $currentPartStart+=$splitMode;
            }
        }else{
            $tempFile=$origFile;
            $back=0;
            $endFlag=1;
        }
        if($back==0){
            my $fileRuntime=`ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$tempFile"`;chomp($fileRuntime);
            if(($splitMode ne "n")&&($fileRuntime<$splitMode*60)){
                $endFlag=1;
            }
            if($fileRuntime>0){
                push @convertedFileRuntimes,$fileRuntime;
                my $bookFile="$bookName/".sprintf("%04d", scalar(@convertedFileRuntimes))." $bookName 0000.awb";
                $back=system("./encoder-new -rate $bitRate -mono -ff raw -if \"$tempFile\" -of \"$bookFile\"");
                if($origFile ne $tempFile){
                    unlink $tempFile;
                }
                if((stat($bookFile))[7] == 0){#encoder-new does not ouput useful return codes so check the file size
                    print STDERR "ERROR: Could not convert temporary wav file to awb plus Playaway file.\n";
                    exit 7;
                }
            }else{
                if($origFile ne $tempFile){
                    unlink $tempFile;
                }
            }
        }else{
            print STDERR "ERROR: Could not convert $origFile to temporary wav file.\n";
            exit 6;
        }
    }while($endFlag==0);
}
my $preAllModels="AWBVOL082002SLD090080PUP003NMD";
my $preLight=$preAllModels.sprintf("%03d",scalar(@convertedFileRuntimes))."BLN020BLP020ELA";
my $preClassic=$preAllModels.sprintf("%03d",scalar(@convertedFileRuntimes));
my $post="COP0000\r\n";
my $mid="000";
my $runtimeCnt=0;
foreach(@convertedFileRuntimes){
    $runtimeCnt+=$_;
    $mid.=sprintf("%03X",int($runtimeCnt/60));
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
    my $fileArray=$_[0];
    my $runtimeSum=$_[1];
    if(opendir(D,".")){
        foreach(readdir(D)){
            my $entry=$_;
            if(($entry ne ".")&&($entry ne "..")&&(($entry=~/\.mp3$/i)||($entry=~/\.amr$/i)||($entry=~/\.awb$/i)||($entry=~/\.wav$/i)||($entry=~/\.m4a$/i)||($entry=~/\.ogg$/i))){
                push @{$fileArray},$entry;
                my $runtime=`ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$entry"`;chomp($runtime);
                print ".";
                ${$runtimeSum}+=$runtime;
            }
        }
        closedir(D);
        @{$fileArray}=sort @{$fileArray};
    }else{
        print STDERR "ERROR: Could not open directory . for reading.\n";
        exit 2;
    }
    ${$runtimeSum}=int(${$runtimeSum});
}

sub preFlightChecks{
    my $back=system("ffmpeg -h > /dev/null 2>&1");
    if($back != 0){
        print STDERR "ERROR: ffmpeg could not be found.\n";
        exit 20;
    }
    $back=system("ffprobe -h > /dev/null 2>&1");
    if($back != 0){
        print STDERR "ERROR: ffprobe could not be found.\n";
        exit 20;
    }
    $back=system("mktemp -u -p \".\" > /dev/null 2>&1");
    if($back != 0){
        print STDERR "ERROR: mktemp does not seem to work.\n";
        exit 20;
    }
    $back=system("./encoder-new > /dev/null 2>&1");
    if($back != 256){#exit code 1, which is normal exit code when no encoding happens
        print STDERR "ERROR: encoder-new binary not found.\n";
        exit 20;
    }
}
