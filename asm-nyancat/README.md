asm-nyancat
===========

A bare metal assembly implementation of the famous Nyan (Poptart) Cat meme complete with sound.

I was bored one day and decided to try and program in ARM assembly.  I was shocked to find a
forum dedicated to this on the Raspberry Pi site.  I learned quite a bit about how to set up
the frame buffer and then later how to send audio to the audio out jack from several of the posts
there.

Optionally build it or just copy the already built kernel.img (this will replace Linux) to the boot partition
of the SD card, plug in your Pi and enjoy.

Note: The audio only will play out of the 3.5mm audio jack not via HDMI, you need to talk to the
Video Core to do that, I haven't quite figured out how to do that yet.  The video will work with
either the composite port or HDMI.

Building
--------

You'll need a ARM port of the GCC tool chain, you can get this from
https://launchpad.net/gcc-arm-embedded/+download

Run build.sh, this will assemble the source and then append the media data files to the end of the
binary image and the result will be kernel.img

Copy that to an SD card that has the base Raspberry Pi firmware boot files:
bootcode.bin, fixup.dat, fixup_cd.dat, fixup_x.dat, start.elf, start_cd.elf, start_x.elf

You might need to make or tweak a config.txt file for any HDMI settings, I'm using 1024x768 16 bit color for
this program.  I've included one that works for me in the project.

