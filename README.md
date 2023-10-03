# Play more on Playaway
[Playaways](https://playaway.com/) are small audio players that mostly contain audio books.  
![image](pics/playaway_device.jpg)  
They can be found in public libraries and are rather expensive compared to other general purpose audio/MP3 players.  
Still though they concentrate on the basics and doing these basics well. It seems they follow one of the Unix philosophy cornerstone to [do one thing and do that well](https://en.wikipedia.org/wiki/Unix_philosophy). The devices have huge physical buttons, a display (that is not really needed), a standard 3.5mm headphone jack, remember exactly the listening position and run for 20+hrs on a standard AAA battery. You take the device as a normal book and start listening. No smartphone or other device features that could distract you from just diving in to the story the author wants to present to you.  
The devices can be bought with one single audio book on them and no (official) way of changing this. If bought new they [start at](https://shop.playaway.com/playaway) approx. 60€ (October 2023) depending on the audio book stored on them.  
  
This repository shows an unofficial way to make more use of the playaway hardware by allowing to put other audio books on them and therefore also avoiding e-waste. This currently requires opening the device and soldering wires on the printed circuit board as well as installing and running the software in this repository. All your might be existing warranty is then lost.  
  
All my findings are built on the great prework of:  
[Teardown video with different models](https://www.youtube.com/watch?v=CapoZ9ZmoAM)  
[Teardown article with high res pictures](https://www.mitsake.net/2019/06/playaway-audiobook-teardown/)  
  
Their research led me to buying one as it seemed to me that the most important part of actually storing another audio book on it was just a little additional step. As it turned out it was.  

# The hardware
I bought my playaway as a surprise offer for 8.96€. This device is now not thrown away but I could learn with it and by reading this you will too.  
![image](pics/playaway_offer.png)  
  
I got a very used model with a leaked battery in the case. I replaced the battery switched it on and it worked.  
[If you can not open it you don't own it.](https://valpo.life/article/if-you-cant-open-it-you-dont-own-it/) I opened it up to solder a USB cable as described by the prework mentioned earlier:  
![image](pics/playaway_internal_usb.jpg)  
  
My model has an 128MB flash chip. It seems there are other hardware models with 256MB.  
I cut a hole in the case and used hot glue to mechanically fix the cable and were ready to go for further research:  
![image](pics/playaway_hot_glue.jpg)![image](pics/playaway_hole.jpg)  
![image](pics/playaway_final.jpg)

# File system structure
Once connected I was greeted with the following file system layout:  
![image](pics/playaway_initial_filesystem.png)  
  
The flash has the following partition table:  
![image](pics/playaway_partition.png)  
  
We can use 105MB for audio files. I assume the missing few MBytes are used for the firmware and can not be accessed via USB. The SOC can boot firmware from an attached flash memory.  
But my goal was to put other audio books on it, not to understand every single aspect. After testing a lot with what files can be deleted it turned out only the .awb files and the PATWEAKS.DAT are needed for the SOC firmware to work correctly. The other files store the current listening position and also seem to keep track of the validity of files via CRC method (CMI_CRC.DAT). It is a bare flash chip, so the SOC firmware must keep track of errors that usually is being dealt with via wear leveling if using an SSD within their firmware.  

### Creating AWB files
The format used is [AMR-WB+](https://en.wikipedia.org/wiki/Extended_Adaptive_Multi-Rate_%E2%80%93_Wideband). This is a documented codec but not implemented in any well used open source software. Ffmpeg as a very long standing [feature request](https://trac.ffmpeg.org/ticket/6140).  
It was necessary to get the freely available (windows only...mmppff) decoder and encoder from [here at 3GPP](https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=1451).  
Only the files encoder.exe and er-libisomedia.dll are needed to encode new AMR-WB+ files. The encoder.exe runs without any problems using wine.  
The encoder needs a .wav file input. I experimented a bit and was successful with generating a .wav file from e.g. an MP3 using ffmpeg with the following command line.  
`
ffmpeg -i input.mp3 -f wav -c:a pcm_s16le -ac 1 -ar 16000 -empty_hdlr_name 1 -fflags +bitexact -flags:v +bitexact -flags:a +bitexact -map_metadata -1 input_as_wav.wav
`  
This command line assures that there is no metadata in the .wav file as the encoder will otherwise not be able to open the .wav. It took me a while to figure that out. I have also not yet experimented with stereo and other sample rates than 16kHz.  
  
The generated .wav can now be encoded into an AMR-WB+ file with the following command using an installed wine and the encoder.exe which needs the er-libisomedia.dll in the same directory:  
`
wine encoder.exe -rate 10 -mono -ff raw -if input_as_wav.wav -of "0001 BookName 0000.awb"
`  
I figured out that the lowest bitrate parameter (-rate) for my playaway is 10. Anything lower resulted in stuttering playback. The highest tested bitrate is 12 but I assume all higher bitrates are no problem. The original files on my playaway were encoded with 36kbit/s. 10 sounds still good enough for me and as we only have 105MB we want to test the lower boundaries. With 105MB and 10kbit/s we can store approx. 23hrs. on the playaway. I assume that playaways that have longer audio books on them come with a bigger flash memory chip.   
I was sticking with the filenaming convention I found and did not test any other versions. The first 4 digit number is the chapter while the last 4 digit number is always 0000. I assume the last 4 digit number comes in use when multiple audio books are placed on the playaway.  
  
### Generating PATWEAKS.DAT
The .awb files are of no use if there are not referenced correctly in the PATWEAKS.DAT. The original I found on my playaway looked like this:  
`
AWBVOL082002SLD090080PUP003NMD003BLN020BLP020ELA00003B07D0BECOP5521~ 2007 FonoLibro Inc.00000019^ 2006 J.J. Bentez,222006 Editorial Planeta0000
`  
A (more or less) human readable file in plain ASCII with an ending windows enter. Comparing this string with the one from the video (see prework links above) showed the similarities and differences. A lot of debugging and testing later the following can be documented:  

**First part:** `AWBVOL082002SLD090080PUP003`  
Currently unknown what it means. I left it as it was.  

**Middle part I:** `NMD003BLN020BLP020`  
In this part only NMD003 has relevance. 003 determines the number of files that make the audio book. This needs changing if your audio book has more or less files. It must match the .awb files on the playaway *exactly* or the SOC firmware shows an error.  
  
**Middle part II:*** `ELA00003B07D0BE`  
This took the longest to figure out and it's still not perfect but good enough. The numbers are groups by hex digits of three:  
`000 03B 07D 0BE`  
Each group represents one chapter(=.awb file) and the length of the progress meter which is displayed.  
Here on the first chapter the length 000 is given which means an almost not visible progress meter. Chapter 2 raises the progress to 03B. This number actually represents the length of the first chapter. The value is determined by the length of the (first) chapter in minutes. For my playaway the three different chapters had the length of 64,70 and 70 minutes.  
  
Time difference: 000-03B = 59minutes  
Time difference: 03B-07D = 66minutes  
Time difference: 07D-0BE = 65minutes  
  
We can see that the times do not match 100%. It is unclear why the numbers do not match better. I tested different files which are smaller/shorter so that the progress meter also changes faster and it worked good enough. Also a 1pixel difference because of one wrong value is hardly noticeable once the audio book is longer than one hour.  
  
**Last part:** `COP5521~ 2007 FonoLibro Inc.00000019^ 2006 J.J. Bentez,222006 Editorial Planeta0000`  
It is unclear what COP5521 means. But the following string is shown when the playaway starts playing the first chapter of an audio book for a few seconds until the play time is displayed. It has an internal structure which seems to determine the position on the display and the time it is displayed. I have not yet checked deeper into this sub structure.  
It can be left out without problems by adding a space after COP5521 followed by a windows enter.  

# The Perl script
The script assumes it can write to the current directory and has only been tested with Linux. It assumes ffmpeg, wine and mktemp is callable. No additional modules are needed.  
It expectes all files to be converted (.mp3/.amr/.awb) within the same directory where it is placed as well as the encoder.exe and er-libisomedia.dll.  
It will create a local directory based on the book name you choose and place all converted files there to copy on your playaway. All existing files of the playaway can be deleted or backed up if you need them later.  
The script tries to detect all errors so as long as no "ERROR: ..." message appears everything is ok. The script does not hide the output of the called commands and is therefore very talkative.  
The chapter order is determined by a simple perl sort which sorts based on ASCII position.  
  
# Future ideas
- 3D printed back panel to fit a holding USB socket so that no additional cable is needed  
- Pogo pin adapter + programming station so that no soldering is needed at all  
- more research into the missing currently unknown fields of PATWEAKS.DAT  
