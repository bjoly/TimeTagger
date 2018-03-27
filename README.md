# Time-Tagger firmware for the Atlas-SoC Kit

## Materials :
* DE0-Nano-SoC (from Terasic) Cyclone V FPGA evaluation Board
* SD card image: Altas-SoC (atlas_sdcard_v1.1.img)
  * Linux kernel 4.0
  * Ångström v2014.12 Yocto 1.7
* Desktop PC : CentOS6 (version 2.6.32, release 696.18.7el6, x86_64)
* Software tools : Quartus Prime 17.0, SoC EDS for compilation



## Atlas-SoC Kit Howto

Mains source :
https://rocketboards.org/foswiki/view/Documentation/AtlasSoCDevelopmentPlatform


### Installing Atlas-SoC image on µSD card

https://rocketboards.org/foswiki/Documentation/AtlasSoCSdCardImage

### Connecting via USB-Serial

Add user to `dialout` group for acces to port `ttyUSB0`

		$ sudo usermod -a -G dialout $USER


Install minicom. Enter `sudo minicom -s` to configure.
Under Serial Port Setup choose the following

 * Serial Device: /dev/ttyUSB0 (edit to match the system as necessary)
 * Bps/Par/Bits: 115200 8N1
 * Hardware Flow Control: No
 * Software Flow Control: No
 * Hit [ESC] to return to the main configuration menu

Select Save Setup as dfl to save the default setupSelect Exit.


### Communicate to the SoC Kit by ssh

Define a static IP:
https://rocketboards.org/foswiki/Documentation/SettingAStaticIPAddressInAngstrom

		root@atlas_sockit:~# connmanctl config <connection> --ipv4 manual <ip address> <netmask> <gateway>

The it is possible to connect via `ssh` and send programming files by `scp`.


#### Automate ssh login using RSA key pair

https://serverfault.com/questions/241588/how-to-automate-ssh-login-with-password

From Desktop PC : (no passphrase, hit `enter` 3 times)

    $ ssh-keygen -t rsa -b 2048
    Generating public/private rsa key pair.
    Enter file in which to save the key (/home/username/.ssh/id_rsa):
    Enter passphrase (empty for no passphrase):
    Enter same passphrase again:
    Your identification has been saved in /home/username/.ssh/id_rsa.
    Your public key has been saved in /home/username/.ssh/id_rsa.pub.

Copy the keys to the server:

    $ ssh-copy-id root@192.168.1.26
    id@server's password:


Then log in:

    $ ssh root@192.168.1.26
    root@192.168.1.26:~$



### FPGA programming

During tests, the FPGA should be programmed using the dedicated miniUSB port with Quartus programmer. The program is lost at power down.

For operation, the FPGA is programmed during the boot. The method is detailed below.

source :
http://rocketboards.org/foswiki/Documentation/GSRD131ProgrammingFPGA

The MSEL switches must be in FPPx32 configuration
(1:on 2:off 3:on 4:off 5:on 6:on).


#### Creation of a "raw binary file"

On the Quartus PC, in the "embedded_command_shell", generate a .rbf file from the .sof:

		quartus_cpf -c -o bitstream_compression=on ./soc_system.sof ./soc_system.rbf

(In principle this can be done using Quartus GUI, but i did not find the good options. an error occurs when the resulting .rbf file is loaded in the FPGA).

#### Modification of boot script

In the Atlas-SoC reference design, the bootloader u-boot runs a script "u-boot.scr" located in SD card, partition 1. This script points to a reference .rbf file also
present in the boot partition.

We modify the boot script to change the .rbf file path/name, and we copy our .rbf file to the boot partition.

This can be done either
* by moving the µSD card from the board to the PC's reader
* via the embedded linux

In each case, you must
* mount the boot partition:

		root@atlas_sockit:~# cd /media
		root@atlas_sockit:~# mkdir -p sdcard
		root@atlas_sockit:~# mount /dev/mmcblk0p1 sdcard

* Edit u-boot.scr. For example, i replaced `ATLAS_SOC_GHRD/output_files/ATLAS_SOC_GHRD.rbf`
by `ATLAS_SOC_GHRD/output_files/soc_system.rbf`

* From desktop PC, copy "soc_system.rbf" to SD card boot partition

		$ scp soc_system.rbf root@192.168.1.2:/media/sdcard/ATLAS_SOC_GHRD/output_files/

* do not forget to unmount

		root@atlas_sockit:~# umount /media/sdcard

Now, "soc_system.rbf" will be loaded in the FPGA at the next boot.


## System date/time

The board does not include a battery-powered RTC (Real Time Clock).
As a consequence, the date is wrong after boot.

We need a correct time to identify the data files (one file per "run", file name includes "epoch" timestamp).

The "Network Time Protocol" is the best solution for automatic synchronisation at startup. However it may not be usable in our case.

A less precise but simple alternative is shown below.

### Set date/time (manually / by script)

First (once for all), define timezone

    root@atlas_sockit:~# timedatectl set-timezone europe/Paris

The, the command below sets the date

    root@atlas_sockit:~# date -s '2018-03-23 11:18:28'

And the `date` command returns date and zone

        root@atlas_sockit:~# date
        Fri Mar 23 11:18:28 CET 2018

The idea :
  * read the date on a reference server in the local network,
  * set the local date accordingly

We need to run a command via ssh
https://www.cyberciti.biz/faq/unix-linux-execute-command-using-ssh/
(ssh login must have been automatized with passphraseless key pair).

The trick is to read the date on one side and set it on the other side using a common string formatting, "epoch time", the time in seconds since 1st jan, 1970 at 00:00:00. To print it:

    $ date +%s
    1521802123

And to set it:

    root@atlas_sockit:~# date -s @1521802123

Combine them with command substitution either from Altas-Soc Kit :

    root@atlas-sockit:~# date -s @$(ssh <user@server> 'date +%s')

This command should be run initially by the data acquisition program (or script).

Using this hack, we achieve ~1s precision.
