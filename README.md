# **Overview**

This is a community branch of the Smoothieware firmware for the Makera Carvera
CNC Machine. It is also part of the Carvera Community Org, which includes these
other projects: [Machine Profiles](https://github.com/Carvera-Community/Carvera_Community_Profiles) -
Post processors, 3d design files, and tool libraries for various CAM/CAD
programs

Open Source Version of the Carvera
[Controller](https://github.com/Carvera-Community/CarveraController) - includes
builds for linux and macOS. There is a javascript based controller alternative
in the works as well

[Trello](https://trello.com/b/qKxPlEbk/carvera-community-firmware-controller-and-other-tech)
- for seeing progress on features and making recommendations

**NOTE** it is not necessary to build the firmware yourself unless you want to.
prebuilt binaries are available
[here](https://github.com/Carvera-Community/Carvera_Community_Firmware/releases).
There will be periodic stable releases that line up with controller releases,
and rolling beta versions to test new features.

Smoothie is a free, opensource, high performance G-code interpreter and CNC
controller written in Object-Oriented C++ for the LPC17xx micro-controller ( ARM
Cortex M3 architecture ). It will run on a mBed, a LPCXpresso, a SmoothieBoard,
R2C2 or any other LPC17xx-based board. The motion control part is a port of the
awesome grbl.

# Documentation and resources

- [Community feeds, speeds and
  accessories](https://docs.google.com/spreadsheets/d/1i9jD0Tg6wzTpGYVqhLZMyLFN7pMlSfdfgpQIxDKbojc/edit) Comprensive
  resource for G/M codes, config variables, console commands, as well as feeds & speeds recommendations.  
- [Makera website](https://wiki.makera.com/en/home), [supported codes](https://wiki.makera.com/en/supported-codes), [feeds & speeds](https://wiki.makera.com/en/speeds-and-feeds)
- [Smoothieware documentation](https://smoothieware.github.io/Webif-pack/documentation/web/html/index.html)
- [Carvera A to Z](https://carvera-a-to-z.gitbook.io/carvera-a-to-z) - A work in progress wiki for all sorts of information on getting started with the Carvera CNC machine

_**More from the Carvera Community**_

- [Carvera Controller](https://github.com/carvera-community/carvera_controller/) - community controller with extensive additional features and support for community firmware features.
- [Carvera Community Profiles](https://github.com/Carvera-Community/Carvera_Community_Profiles) - profiles and post-processor for various third party CAM software.
- [Carvera CLI](https://github.com/hagmonk/carvera-cli) - CLI interface to Carvera for scripting and device management.

_**Other open source tools**_

- https://cc.grid.space/ 
- https://github.com/GridSpace/carve-control
- https://github.com/AngryApostrophe/Clout
- https://cnc.js.org/ 
- https://github.com/cncjs/cncjs-pendant-boilerplate


Work in progress wireless 3 axis touch probe: will be released open source and open hardware along with a purchasable version https://github.com/faecorrigan/Open-Source-3-axis-CNC-Touch-Probe

# Filing issues and contributing 

Please follow [the Smoothieware issue template](https://github.com/Smoothieware/Smoothieware/blob/edge/ISSUE_TEMPLATE.md) when filing bugs against this repo.

Contributions very welcome! 

- Open an
[issue](https://github.com/Carvera-Community/Carvera_Community_Firmware/issues)
either on github, trello, or message one of the admins. Issues can be for
bugfixes or feature requests. 
- Test beta versions of the firmware and give bugreports/feedback
- Contribute pull requests to the project
- Contribute to the [A_To_Z wiki](https://github.com/SergeBakharev/carvera_a_to_z)

Carvera Community Firmware uses the same guidelines as upstream Smoothieware
- http://smoothieware.org/coding-standards
- http://smoothieware.org/developers-guide
- http://smoothieware.org/contribution-guidlines

# Donate

This particular branch of the carvera firmware is maintained by [Fae
Corrigan](https://www.patreon.com/propsmonster) For smoothieware as a whole: the
Smoothie firmware is free software developed by volunteers. If you find this
software useful, want to say thanks and encourage development, please consider a
[Donation](https://paypal.me/smoothieware)


# Building the firmware

## Toolchain

There are two GCC toolchains that have been tested with the firmware. In both cases,
simply ensure the `bin` directory for the toolchain is in your path. For example:

```bash
PATH=$PATH:$PWD/gcc-arm-none-eabi/bin make ...
```

### GCC 4.8

This is the ancient toolchain used upstream by Makera and should be the default
for all users until otherwise advised. Visit
[Launchpad](https://launchpad.net/gcc-arm-embedded/4.8/4.8-2014-q1-update/) and
download the _gcc-arm-none-eabi_ variant appropriate for your platform.

### GCC 10.3 (Experimental!!)

The firmware has been updated to support the significantly newer (but still
quite old) GCC 10.3, which is [available
here](https://developer.arm.com/downloads/-/gnu-rm). Firmware built with this
toolchain *has not* undergone rigorous cycle time in real world machines. Once
stablized we'll continue to push forward and adopt a modern, supported version
of GCC.

## Build

With the appropriate toolchain in your PATH:

```bash
# For macOS:
make -j$(sysctl -n hw.ncpu) AXIS=5 PAXIS=3 CNC=1

# For Linux:
make -j$(nproc) AXIS=5 PAXIS=3 CNC=1

# For Windows: 
make -j%NUMBER_OF_PROCESSORS% AXIS=5 PAXIS=3 CNC=1
```

It's usually advisable to `make clean` regularly. Because `-j` reduces build
time to <10s on modern hardware, it's feasible to run it prior to every build.

Flags that can be useful:

`VERBOSE=1` prints compiler and linker invocations

`VERSION=string` sets the version string as reported by `version` in the console. This can be
helpful if you need to verify the bootloader really picked up your new firmware. e.g.

```bash
make -j($sysctl -n hw.cpu) AXIS=5 PAXIS=3 CNC=1 VERSION=bobby-`date +%Y-%m-%d-%H-%M-%S`
```

Additional guides related to building Smoothieware [can be found
here](https://smoothieware.github.io/Webif-pack/documentation/web/html/compiling-smoothie.html).

## Uploading

The build process will output `LPC1768/main.bin`. It should be approximately
500KB in size. There are several strategies to load this onto the machine.

### Carvera Controller

0. Copy `LP1768/main.bin` to `firmware.bin`
1. Connect to the machine (note: USB will be quite slow)
2. Select the hamburger menu (top right)
3. Choose update (up arrow)
4. Choose Firmware
5. Choose Update
6. Navigate to your local `firmware.bin`
7. Choose Upload
8. Choose Reset

### Carvera CLI

Follow instructions to [Install Carvera CLI](https://github.com/hagmonk/carvera-cli/).

```bash
uvx carvera-cli -d <ip-or-usb-port> upload-firmware --reset ./LPC1768/main.bin
```

Carvera CLI takes care of naming the file correctly and verifying its MD5. Omit
`--reset` if you'd like to reset later.

### microSD card

> [!IMPORTANT]
> Be prepared to do this if you're making significant firmware changes. Trust me!

It's strongly recommended to make a copy of your `config.txt` on the microSD
card, in case you need to format or replace the card (see below).

On C1 models:

* Although the microSD card is "reachable" without the back cover off, it can
  be very beneficial to install an microSD extension cable
* If your Mac/PC has a full sized SD card reader, there are variants that adapt
  from microSD to SD. 
* Ensure the connection is snug! I've seen errors that have turned out to be a
  loosely fitting SD extension cable.
* It's possible to insert the microSD card, miss the surface mounted slot, and
  push it into the controller board enclosure. Don't panic! Removing the four
  phillips head screws from the enclosure will allow you to retrieve it.

_**Prepping the microSD card**_

> [!WARNING]
> USB-C cable connections will energize the controller board even when mains
> power is off! Remember to disconnect before removing or inserting the microSD card.

The most reliable process appears to be to remove `FIRMWARE.CUR` and allow the bootloader
to copy `firmware.bin` over each time.

A paranoid approach (on macOS):

```bash
md5sum LPC1768/main.bin && \
    cp LPC1768/main.bin /Volumes/SD/firmware.bin && \
    [ -f /Volumes/SD/FIRMWARE.CUR ] && \
    rm /Volumes/SD/FIRMWARE.CUR ;\
    md5sum /Volumes/SD/firmware.bin && \
    sleep 1 && \
    ls -l /Volumes/SD && \
    diskutil umount /Volumes/SD/
```

_**Booting from the microSD card**_

0. Ensure the machine is powered down (including controller board!)
1. Insert the card.
2. Power on the machine (or energize the controller board if debugging)

After a brief moment of anxiety, the machine should wake up. The front LED (on
C1 at least) should transition from very dim green, to bright blue, then boot.

*If stuck on dim green* - the bootloader is unhappy with the firmware. This
could include having used the wrong filename, the firmware is not a valid
executable, the microSD card cannot be read, and so on.

*If stuck on bright blue but machine is dark, and stays dark* - the bootloader
jumped into your firmware, but the firmware has not entered the main event loop.
The most common cause for this will be having used the `ENABLE_DEBUG_MONITOR`
(see below) and forgotten to remove it. 

*If cycling between dim green and bright blue* - the bootloader is happy, but
the firmware is not. It is likely this will happen roughly every 10s, as that is
the default watchdog timeout after which the firmware automatically resets.
Probable cause will be a firmware crash.

# Debugging

The community firmware supports attaching GDB over a serial connection. A special debug
build is not required, although some debug specific build flags can be useful.

## Setup

As the serial port is also used for machine control, it's highly recommended to
disable the use of the serial port for this purpose, allowing GDB to stay
attached. To send commands to the machine during debugging, use the wifi
connection via Carvera Controller or Carvera CLI.

Additionally, the watchdog timer **_must be disabled_**, otherwise the device will
reboot after being trapped by the debugger.

The following flags can be set in config.txt or via the console, after which a
reboot is required.

```
# Disable the watchdog timer
config-set sd watchdog_timeout 0

# Make the serial port exclusive for GDB
config-set sd disable_serial_console true

# Optional: stop in the debugger if the machine enters a halt state
config-set sd halt_on_error_debug true
```

When making deeper modifications to the firmware, troubleshooting boot failures,
tracking memory allocations, and so on, you will want a firmware build with the
`ENABLE_DEBUG_MONITOR=1` compile time flag set. This flag traps the debugger
during [build/mbed_custom.cpp](build/mbed_custom.cpp) in `_start`, about as
early in the firmware as you can get. Not just prior to `main()`, but prior to
to C++ static constructors, SRAM region setup, etc.

> [!IMPORTANT]
> Another reminder that the USB-C connection will power the controller board.
> You can get a surprising amount of work done without turning on mains power!

Before starting work with GDB, it can be helpful to create a `.gdbinit` file that
instructs GDB to remember your command history:

```gdb
# in ~/.gdbinit
set history save on
set history filename ~/.gdb_history
set history size 10000
```

## Attaching GDB

> [!IMPORTANT] 
> Ensure that your `main.bin`, `main.elf`, and source code all line
> up exactly. Otherwise you will have a very confusing debug experience.

A script has been added to kick off GDB based on your detected toolchain.

* macOS / Linux: [mri/gdb.sh](mri/gdb.sh)
* Windows: [mri/gdb.ps1](mri/gdb.ps1)

```bash
# unix version
./mri/gdb.sh <your-serial-device>
```

If you omit the path to your serial device, the script will make an educated
guess. It's best to just give it the right path :) 

If you haven't set a GCC toolchain accessible in your `PATH`, the script will go
looking for something sensible in the repo. If it finds multiple GCC toolchains
it will pick the most recent one.

The script automatically loads [mri/init.gdb](mri/init.gdb) which contains some
helpful functions you might need while connected to the firmware. These are
discussed below.

The script will output `mri.log`, which contains a log of the read/write
communication between GDB and the device. This can be handy when verifying if
the device stopped responding.

> [!WARNING]
> Since the GCC 4.8 toolchain is old enough to go to the cinema by itself, at
> least on macOS it's not possible to use that toolchain for GDB. Thankfully,
> GDB is still GDB, and you can happily use a working GDB from a modern
> toolchain to attach.

### Controlling execution

* Hit `ctrl-c`. You will end up at whatever random instruction happened to be
  running at that moment.
* Enable the config variable `halt_on_error_debug` to stop execution on HALT.
* Add a call to `__debugbreak` in your code. Don't use this for regular
  debugging (use breakpoints), instead use this as a kind of "assert" to stop
  execution in unexpected places.
* Send `break` in the console over WiFi.

Note the debugger will also be triggered in the event of an unhandled signal
like a segmentation fault.

## GDB helper commands

### `reset`

Run this command to force a soft reset of the device, similar to calling "reset"
on the MDI console.

Just `ctrl-c` GDB to have it break the connection, since it will need to be
restarted. Re-run `target remote <port>`, or drop out and open the debugger
again.

### `enable-pool-trace`

This command adds breakpoints to predefined symbols inside alloc and dealloc
functions in [src/libs/MemoryPool.cpp](src/libs/MemoryPool.cpp). MemoryPool is a
single contiguous area allocator that manages most of the SRAM region. SRAM is
limited to 32K and is the lowest latency memory available on the LP1768. 

Most modules are placed in dynamically allocated chunks in this region, while a
handful of others (SD filesystem related) are statically placed there at compile
time. Certain modules will continue to make calls to MemoryPool during their
runtime.

This GDB command is primarily useful with `ENABLE_DEBUG_MONITOR=1` because most
activity happens during kernel and module initialization, and by capturing these
logs from firmware boot it's possible to have a complete picture in the case of
a post-initialization crash.

After running this command, execute `continue`. Both alloc and dealloc
breakpoints will output the pointer in question as well as its size. A backtrace
is also logged to identify call sites. This should be enough data to catch
pointer reuse, over-frees, pool exhaustion, and so on.

### `smoothie-full-dump` and `smoothie-mini-dump`

Borrowed from [Smoothieware](http://smoothieware.org/mri-debugging) these
commands dump a variety of program state. 

Especially in the case of the full dump, it's advisable to capture the output to
a file:

```gdb
set logging file <some file>
```

To avoid flooding the console, you can redirect all output to a file. Remember
to disable this afterwards:

```gdb
set logging redirect on
```

### `hardfault-break` and `fault-info`

`hardfault-break` plants a breakpoint on the MCU's `HardFault_Handler`.  
Leave it enabled and any CPU fault (bus/usage/memory) will pause execution the
instant it occurs, letting you inspect the exact crashing instruction.

`fault-info` prints the four System Control Block registers the Cortex-M3
records after a fault (`HFSR`, `CFSR`, `BFAR`, `MMFAR`).  
Refer to the LPC176x User Manual (chapter 32) or ARM "Cortex-M3 Devices Generic
User Guide" (section 4.3) for the meaning of each bit or address.

Together these commands tell you whether a reset was triggered by your firmware
(null pointer, invalid memory write, stack overflow, etc.) or something more
serious such as corrupted memory that could point to hardware issues.

Why not simply let GDB 'catch' the crash? On bare‑metal Cortex‑M parts there is
no OS to raise a UNIX‑style segmentation fault.  Unless you set this breakpoint
the CPU will dive into HardFault_Handler, trash the original register state,
print a message, and usually reset before the debugger ever sees the real
failure.  hardfault‑break stops execution **at the exact vector entry**,
preserving the stacked PC/LR so you can see where things truly went wrong.

### Reconnecting

When the firmware restarts, you'll lose your GDB connection. Rather than
restarting GDB, you can run:

```gdb
target remote <your serial dev>
```

### Scripting

Without turning this into a full guide on GDB, it's worth noting that you will
rapidly find a need for aliasing common commands and running pre-canned routines
repeatedly.

These can be placed in your `~/.gdbinit` or loaded from a file in GDB with
`source`. The aforementioned [mri/init.gdb](mri/init.gdb) functions are loaded
for you and function similarly.

```gdb
# alias commands
alias -a binit = "break main.cpp:init"

# define a command
define dumpmem
  echo --- Memory Pool Dump ---\n
  p _AHB0
  p _AHB1
end

# run a command every time you run 'next'
define hook-next
    dumpmem
end

# run commands when a breakpoint is hit
break MemoryPool::alloc if nbytes >= 5000
commands
  printf "--- Large AHB Pool Allocation (%lu bytes) ---\n", nbytes
  printf "Call Stack:\n"
  bt
  printf "--------------------------------------------\n"
  cont
end
```

# License

Smoothieware is released under the GNU GPL v3, which you can find at
http://www.gnu.org/licenses/gpl-3.0.en.html MRI is released under Apache 2.0,
which you can find at https://www.apache.org/licenses/LICENSE-2.0

