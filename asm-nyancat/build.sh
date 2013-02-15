ARMGCC=~/rpi/gcc-arm-none-eabi-4_6-2012q2/bin
PROG=rpi-nyancat

$ARMGCC/arm-none-eabi-as $PROG.s -o $PROG.o
$ARMGCC/arm-none-eabi-ld $PROG.o -T memmap -o $PROG.elf
$ARMGCC/arm-none-eabi-objdump -D $PROG.elf > $PROG.list
$ARMGCC/arm-none-eabi-objcopy $PROG.elf -O binary $PROG.img
cat $PROG.img nyan16.dat nyan.wav > kernel.img
