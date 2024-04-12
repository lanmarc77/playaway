#!/usr/bin/perl
use strict;

# This script scans a given flash dump of a Playaway, tries to find
# the filesystem and extracts it to a new file ready for mounting.
# The script assumes 2048+64 bytes page size which should be working for 1/2/4 Gbit flash chips.

if(@ARGV!=1){
    printHelp();
    exit;
}

my $source=@ARGV[0];
my $pageSize=2048;
my $spareSize=64;
my $pagesPerBlock=64;
my $emptyBlock="";
for(my $i=0;$i<$pageSize*$pagesPerBlock;$i++){
    $emptyBlock.=chr(0xFF);
}

my @blockUsage=getMapXZones($source);
extractFileSystem($source,\@blockUsage);
print "Finished OK.\n";


exit;


sub extractFileSystem{
    my $s=$_[0];
    my @blocks=@{$_[1]};
    my $searchState=0;
    open(T,">".$s.".filesystem");
    my $cnt=0;
    foreach(@blocks){
	my $blockNumber=$_;
	if($blockNumber!=0xFFFF){#ignore everything until first non empty block
	    $searchState=1;
	}
	if($searchState==1){#start extracting after first time non empty block was detected
	    if($blockNumber==0xFFFF){#empty filesystem area, just put in an empty block
		print T $emptyBlock;
	    }else{
		printf "Getting block $blockNumber from address: %12x targetAddress: %12x \n",($blockNumber*($pageSize+$spareSize)*$pagesPerBlock),tell(T);
		print T getSortedBlock($s,$blockNumber);
	    }
	}
    }
    close(T);
}

sub getMapXZones{
    my $s=$_[0];
    my %maps;
    if(open(S,$s)){
	binmode S;
	my $searchState=0;
	do{
	    my $buf="";
	    my $result=read S,$buf,$pageSize+$spareSize;
	    if($result!=$pageSize+$spareSize){
        	die("Premature file end.\n");
	    }
	    my ($magic, $length, $start,@values) = unpack 'a8 x8 L L S1012', stripEccAndMetaData($buf);
	    my $magic2=getPageType($buf);
	    if(($magic eq "pamxenoz")&&($magic2 eq "LBAM")){
		$maps{$start."\|".$length}=\@values;
		$searchState=1;
	    }elsif(($searchState==1)&&($magic ne "pamxenoz")){
		my @all=();
		foreach(sort keys(%maps)){
		    my($start,$length)=split(/\|/,$_);
		    my @v=@{$maps{$_}};;
		    @v=@v[0..$length-1];
		    push @all,@v;
		}
		my $cnt=0;
		foreach(@all){
		    if(($cnt%10==0)||($cnt==0)){printf "\n%5i ",$cnt;}
		    $cnt++;
		    printf("%8i",$_);
		}
		print "\n";
		close(S);
		return @all;
	    }
	}while(1);
    }else{
	die("Could not open $s\n");
    }
}

sub stripEccAndMetaData{
    my $buf=$_[0];
    my ($b0,$ecc0,$b1,$ecc1,$b2,$ecc2,$b3,$ecc3,$meta,$eccMeta)=unpack 'a512 a9 a512 a9 a512 a9 a512 a9 a19 a9', $buf;
    return $b0.$b1.$b2.$b3;
}

#returns a block of pages sorted based on meta data
sub getSortedBlock{
    my $s=$_[0];
    my $bn=$_[1];
    if(open(S,$s)){
	binmode S;
	seek(S,$bn*($pageSize+$spareSize)*$pagesPerBlock,0);
    my $buf="";
	my $result=read S,$buf,($pageSize+$spareSize)*$pagesPerBlock;
	if($result!=($pageSize+$spareSize)*$pagesPerBlock){
	    die("Premature file end.\n");
	}
	my @unsorted=unpack("(A".($pageSize+$spareSize).")*",$buf);
	my @sorted=unpack("(A".($pageSize).")*",$emptyBlock);
	foreach(@unsorted){
	    my $pageOrder=getPageOrder($_);
	    if($pageOrder>=$pagesPerBlock){#empty page in block
		#print "Ignored";
	    }else{
		@sorted[$pageOrder]=stripEccAndMetaData($_);
	    }
	}
	close(S);
	$buf="";
	foreach(@sorted){
	    $buf.=$_;
	}
	return $buf;
    }else{
	die("Could not open $s\n");
    }
}


sub getPageOrder{
    my $b=$_[0];
    my ($ignored,$order)=unpack 'a2088 S', $b;
    return $order;
}

sub getPageType{
    my $b=$_[0];
    my ($ignored,$type)=unpack 'a2086 a4 ', $b;
    return $type;
}


sub printHelp{
    print "This script extracts the file system from a Playaway flash dump.\nThe exported file system is named as the flash dump file with .filesystem extension added.\n\nUsage:\n $0 [flashDump.bin]\n";
}
