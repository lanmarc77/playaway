# POC for low level Playaway STMP3770 access

The STMP3770 has a special USB recovery mode that is handles by the chip ROM. Even if the NAND storage is completely empty
this mode can be activated and the STMP3770 reports as HID device 066f:3770 via USB.  
  
In this USB recovery mode the chip can be communicated with using the BLTC protocol and accepts only valid
signed .sb (secure boot) files. Luckily the [Rockbox project](https://www.rockbox.org) has all the needed tools
that are also part of this directory. And luckily part II: Playaways use the zero "encryption" key.  
  
1. The Playaway needs to be booted into USB recovery mode which is done by soldering a Pull-up resistor (I used 7.5k)
   to 5V to the PCB pin marked as PWR. This pin is actually a direct connection to the STMP3770 PSWITCH pin which
   if pulled up during power on will enable the USB recovery mode.  
2. The tools in the `sbtools` directory need to be compiled by issuing `make` inside the `sbtools` directory.  
3. The example program is compiled by using `compile.sh` and uploaded (root permission needed) by using `upload.sh`.  
  
This example program lets the LCD backlight blink a few times until the whole system is rebooted again.  
  
This POC shows how to execute own code on the STMP3770. To be able to now repair or rewrite the NAND storage of
a Playaway code needs to implemented to create a communication channel with the Playaway (ideally via USB) and then
use this communication channel to read/write the NAND storage.  
This requires understanding the USB subsystem the GPMI subsystem writing a USB CDC ACM driver
a NAND storage driver and a useful protocol.  
  
As the POC shows this is practically possible maybe I will find the motivation to start one day.  
