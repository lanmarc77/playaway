# Play more on Playaway
[Playaways](https://playaway.com/) are small audio players that mostly contain audio books.  
![image](pics/playaway_device.jpg)  
They can be found in public libraries and are rather expensive compared to other general purpose audio/MP3 players.  
Still though they concentrate on the basics and doing these basics well. It seems they follow one of the Unix philosophy cornerstone to [do one thing and do that well](https://en.wikipedia.org/wiki/Unix_philosophy). The devices have huge physical buttons, a display (that is not really needed), a standard 3.5mm headphone jack, remember exactly the listening position and run for 20+hrs on a standard AAA battery. You take the device as a normal book and start listening. No smartphone or other device features that could distract you from just diving in to the story the author wants to present to you.  
The devices can be bought with one single audio book on them and no (official) way of changing this. If bought new they [start at](https://shop.playaway.com/playaway) approx. 40€ (October 2023) depending on the audio book stored on them. Playaway only wants organizational customers (e.g. libraries).  
  
This repository shows an unofficial way to make more use of the Playaway hardware by allowing to put other audio books on them and therefore also avoiding e-waste. This currently requires opening the device and soldering wires on the printed circuit board as well as installing and running the software in this repository. All your might be existing warranty is then lost.  
  
There are different hardware and software versions of the Playaways. Even if they look identical from the outside they might be different. As I have only one Playaway the software and descriptions of this repository might not work for your model. I am interested in learning more about the other models. Please use the [forum](https://github.com/lanmarc77/playaway/issues) to contact me.  
  
All my findings for my model are built on the great prework of:  
[Teardown video with different models](https://www.youtube.com/watch?v=CapoZ9ZmoAM)  
[Teardown article with high res pictures](https://www.mitsake.net/2019/06/playaway-audiobook-teardown/)  
  
Their research led me to buying one second hand as it seemed to me that the most important part of actually storing another audio book on it was just a little additional step. As it turned out...it was.  

# The hardware
I bought my Playaway as a surprise offer for 8,94€. This device is now not thrown away but I could learn with it and by reading the following chapters you will too.  
![image](pics/playaway_offer.png)  
  
I got a very used model with a leaked battery in the case. I replaced the battery switched it on and it worked.  
[If you can not open it you don't own it.](https://valpo.life/article/if-you-cant-open-it-you-dont-own-it/) I opened it up to solder a USB cable as described by the prework mentioned earlier:  
![image](pics/playaway_internal_usb.jpg)  
  
My model has an 128MB flash chip (105MB usable). It seems there are other hardware models with 256MB. I have seen models with runtimes over 50hrs so there must be bigger versions.  
I cut a hole in the case and used hot glue to mechanically fix the cable and were ready to go for further research:  
![image](pics/playaway_hot_glue.jpg)![image](pics/playaway_hole.jpg)  
![image](pics/playaway_final.jpg)

# File system structure
Once connected I was greeted with the following file system layout:  
![image](pics/playaway_initial_filesystem.png)  
  
The flash has the following partition table:  
![image](pics/playaway_partition.png)  
  
We can use 105MB for audio files. I assume the missing few MBytes are used for the firmware and can not yet be accessed via USB. The SOC can boot firmware from an attached flash memory.  
My main goal was to put other audio books on it. After testing a lot with what files can be deleted it turned out only the .awb files and the PATWEAKS.DAT are needed for the SOC firmware to work correctly. The other files store the current listening position and also seem to keep track of the validity of files via CRC method (CMI_CRC.DAT). It is a bare flash chip, so the SOC firmware must keep track of errors that usually is being dealt with via wear leveling if using an SSD within their firmware.  

### Creating AWB files
The format used is [AMR-WB+](https://en.wikipedia.org/wiki/Extended_Adaptive_Multi-Rate_%E2%80%93_Wideband). This is a documented codec but not implemented in any well used open source software. Ffmpeg as a very long standing [feature request](https://trac.ffmpeg.org/ticket/6140).  
It was necessary to get the freely available (windows only...mmppff) decoder and encoder from [here at 3GPP](https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=1451).  
Only the files encoder.exe and er-libisomedia.dll are needed to encode new AMR-WB+ files. The encoder.exe runs without any problems using wine.  
The encoder needs a .wav file input. I experimented a bit and was successful with generating a .wav file from e.g. an MP3 using ffmpeg with the following command line.  
`
ffmpeg -i input.mp3 -f wav -c:a pcm_s16le -ar 44100 -empty_hdlr_name 1 -fflags +bitexact -flags:v +bitexact -flags:a +bitexact -map_metadata -1 input_as_wav.wav
`  
This command line assures that there is no metadata in the .wav file as the encoder will otherwise not be able to open the .wav. It took me a while to figure that out.  
  
The generated .wav can now be encoded into an AMR-WB+ file with the following command using an installed wine and the encoder.exe which needs the er-libisomedia.dll in the same directory:  
`
wine encoder.exe -rate 10 -mono -ff raw -if input_as_wav.wav -of "0001 BookName 0000.awb"
`  
I figured out that the lowest bitrate parameter (-rate) for my Playaway is 10. Anything lower resulted in stuttering playback. The highest tested bitrate is 12 but I assume all higher bitrates are no problem. The original files on my Playaway were encoded with 36kbit/s. Most likely AMR-WB+ mode index 23 with ISF index 13, the best possible mono rate resulting in approx. 6.5hrs playtime. 10kbit/s still sounds good enough for me and as we only have 105MB we want to test the lower boundaries. With 105MB and 10kbit/s we can store approx. 23hrs. on the Playaway. I am convinced that Playaways that have longer audio books on them come with a bigger flash memory chip.  
I was not able to get stereo to play on the Playaway. It did encode everything but the player did not play the file but jumped directly to the next chapter/track.  
I stayed with the file naming convention I found and did not test any other versions. The first 4 digit number is the chapter while the last 4 digit number is always 0000. I assume the last 4 digit number comes in use when multiple audio books are placed on one Playaway.  
I also tested AMR-NB and AMR-WB files but they did not play.  
  
### Generating PATWEAKS.DAT
The .awb files are of no use if there are not referenced correctly in the PATWEAKS.DAT. Solving this was the main puzzling work. The original I found on my Playaway looked like this:  
`
AWBVOL082002SLD090080PUP003NMD003BLN020BLP020ELA00003B07D0BECOP5521~ 2007 FonoLibro Inc.00000019^ 2006 J.J. Bentez,222006 Editorial Planeta0000
`  
A (more or less) human readable file in plain ASCII with an ending windows line break. Comparing this string with the one from the video (see prework links above) showed the similarities and differences. A lot of debugging and testing later the following can be documented:  

**First part:** `AWBVOL082002SLD090080PUP003`  
Currently unknown what it means. I left it as it was.  
  
**Middle part I:** `NMD003BLN020BLP020`  
In this part only NMD003 has relevance (NMD=NumberMeDia?). 003 determines the number of files that make the audio book. This needs changing if your audio book has more or less files. It must match the number of .awb files on the Playaway *exactly* or the SOC firmware shows an error.  
  
**Middle part II:** `ELA00003B07D0BE`  
This took the longest to figure out and it's still not perfect but good enough (ELA=Estimated Length Audio?). The numbers are groups by hex digits of three:  
`000 03B 07D 0BE`  
Each group represents one chapter(=.awb file) and the length of the progress meter which is displayed. Additionally a first entry which is (most likely) always 000.  
Here on the first chapter the length 000 is given which means an almost not visible progress meter if this chapter is selected. Chapter 2 raises the progress to 03B. This number actually represents the time length of the first chapter. The value is determined by the length of the first chapter in minutes. For my Playaway the three different chapters had the length of 64,70 and 70 minutes.  
  
Time difference: 000-03B = 59minutes  
Time difference: 03B-07D = 66minutes  
Time difference: 07D-0BE = 65minutes  
  
We can see that the ELA calculated times do not match 100%. It is unclear why the numbers do not match better. I tested different files which are smaller/shorter so that the progress meter also changes faster and it worked good enough. Also a 1pixel difference because of a slightly off value is hardly noticeable once the audio book is longer than one hour.  
  
**Last part:** `COP5521~ 2007 FonoLibro Inc.00000019^ 2006 J.J. Bentez,222006 Editorial Planeta0000`  
It is unclear what exactly COP5521 means (COP=COPyright?). But the following string is shown when the Playaway starts playing the first chapter of an audio book for a few seconds until the play time is displayed. It has an internal structure which seems to determine the position on the display and the time it is displayed.  
Setting it to COP0000 followed by a windows line break does not display anything.  

# The Perl script
The script assumes it can write to the current directory and has only been tested with Linux. It assumes ffmpeg, wine and mktemp is callable. No additional modules are needed.  
It expects all files to be converted (.mp3/.amr/.awb) within the same directory where it is placed as well as the encoder.exe and er-libisomedia.dll.  
It will create a local directory based on the book name you choose and place all converted files there to copy on your Playaway. All existing files of the Playaway can be deleted or backed up if you need them later.  
The script tries to detect all errors so as long as no "ERROR: ..." message appears everything is ok. The script does not hide the output of the called commands and is therefore very talkative.  
The chapter order is determined by a simple Perl sort which sorts based on ASCII position.  
  
# Other findings

- the Playaway switches off after 8hrs of continuous playback independent of the battery level

  
# Model overview
As described there are different models. It is currently unclear how many hardware/software versions exists. At least the models with a 7 segments display exists and those with a much bigger graphics display.  
If looking at different screenshots ([1](pics/playaway_final.jpg) and [2](pics/playaway_differentDisplay.jpg)) different display layouts seem to exist, which implies different firmware. Look at the small additional number 87 in screeshot 2 which does not exist in 1.  
Some graphics models greet you with either "NOW YOU SEE ME" or "BUILT FOR LISTENING". And finally some graphics model show chapter names on top instead of the current chapter number and total chapters.   
The following table gives an overview of the models researched already and their characteristics.
  
Legend: 
  
* model: S=seven segment version, G=graphics display unknown version, G1=graphics display as in [1](pics/playaway_final.jpg), G2=graphics display as in [2](pics/playaway_differentDisplay.jpg)


| book        | runtime   | bitrate  | release date  | model   | flash |  processor | PCB date | pictures |
|-------------|-----------|----------|---------|-------|------------|----------|------------|------------|
|Six Years by Harlan Coben|10:34:21|?|19.03.2013|S|Hynix H27U1G8F2BTR BC 233AA / 1Gbit|STMP3770 A3 PTX AA1307G TAIW|?| [F](pics/models/sixyearsF.jpg),[B](pics/models/sixyearsB.jpg),PF,[PB](pics/models/sixyearsPB.jpg) (courtesy of [Quick Look & Teardown](https://www.youtube.com/watch?v=CapoZ9ZmoAM))|
|The Breakdown by B.A. Paris|09:20:14|?|18.07.2017|G1|Hynix H27U1G8F2BTR BC 637A / 1Gbit|STMP3770 A3 PTX XAA1B27AE TAIW|?????? 1646| [F](pics/models/thebreakdownF.jpg),[B](pics/models/thebreakdownB.jpg),[PF](pics/models/thebreakdownPF.jpg),[PB](pics/models/thebreakdownPB.jpg) (courtesy of [Quick Look & Teardown](https://www.youtube.com/watch?v=CapoZ9ZmoAM)())|
|Jordan (Caballo de Troya) by J.J. Benitez|02:13:47|36kBit/s|01.09.2009|G1|Hynix H27U1G8F2BTR BC 30AA / 1GBit|STMP3770 A3 PTX A1429U TAIW|?| [F](pics/models/jordanF.jpg),[B](pics/models/jordanB.jpg),PF,[PB](pics/models/jordanPB.jpg)|
|Pelican Brief by J. Grisham|11:37:40|?|?|S|Hynix HY27UF082G2B TPCB 020AA / 2Gbit|STMP3770 A2 PTX AD1023AV TAIW|2009-11-25| [F](pics/models/pelicanbriefF.jpg),B,[PF](pics/models/pelicanbriefPF.jpg),[PB](pics/models/pelicanbriefPB.jpg) (courtesy of [mitsake.net](https://www.mitsake.net/2019/06/playaway-audiobook-teardown/))|


# Future ideas
- 3D printed back panel to fit a holding USB socket so that no additional cable is needed  
- a back sticker that is rewriteable like a chalk board that can hold the currently installed audio book name  
- Pogo pin adapter + programming station so that no soldering is needed at all  
- more research into the missing currently unknown fields of PATWEAKS.DAT  
- trying to get to a SOC firmware channel and write my own  

