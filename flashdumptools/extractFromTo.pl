#!/usr/bin/perl
use strict;


if(@ARGV!=3){
    printHelp();
    exit;
}
my $sourceFile=@ARGV[0];
my $startAddress=hex("0x".@ARGV[1]);
my $extractPages=@ARGV[2];


my $pageSize=2048;
my $spareSize=64;
if($startAddress%($pageSize+$spareSize)!=0){
    die("Startaddress needs to be a multiple of pagesize+sparesize\n");
}
my $targetFile=$sourceFile.".extract_".sprintf("0x%X",$startAddress)."_$extractPages";

my $S;
if(open($S,$sourceFile)){
    binmode $S;
    open(T,">".$targetFile);
    binmode T;
    seek($S,$startAddress,0);
    my $cnt=0;
    do{
	my $buf="";
	my $result=read $S,$buf,$pageSize+$spareSize;
	$cnt++;
	print T stripEccAndMetaData($buf);
	if($result!=$pageSize+$spareSize){
	    print STDERR "Premature file end.\n";
	    exit 1;
	}
	if($cnt>=$extractPages){
	    print "Finished OK.\n";
	    exit 0;
	}
    }while(1);
}else{
    print STDERR "Could not open source file $sourceFile\n";
}

sub stripEccAndMetaData{
    my $buf=$_[0];
    my ($b0,$ecc0,$b1,$ecc1,$b2,$ecc2,$b3,$ecc3,$meta,$eccMeta)=unpack 'a512 a9 a512 a9 a512 a9 a512 a9 a19 a9', $buf;
    return $b0.$b1.$b2.$b3;
}

sub printHelp{
    print "This script extracts parts of a flash dump of a Playaway and strips the spare area.\n\nUsage: $0 [flashDump.bin] [StartAddress hex] [PagesToExtract decimal]\n\n  e.g. $0 flashDump.bin 77A000 64\n";
}

exit;