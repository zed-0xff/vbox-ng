vbox-ng
======

Description
-----------
A comfortable way of doing common VirtualBox tasks.

Installation
------------
    gem install vbox-ng

Usage
-----

    # vbox -h

    USAGE:
    	vbox [options]                           - list VMs
    	vbox [options] <vm_name>                 - show VM params
    	vbox [options] <vm_name> <param>=<value> - change VM params (name, cpus, usb, etc)
    	vbox [options] <vm_name> <command>       - make some action (start, reset, etc) on VM
    
    COMMANDS:
    	acpipowerbutton
    	acpisleepbutton
    	clone
    	delete
    	pause
    	poweroff
    	reset
    	resume
    	savestate
    	show
    	snapshots
    	start
    
    OPTIONS:
        -m, --[no-]multiple              (default: auto) assume <vm_name> is a wildcard,
                                         and run on multiple VMs.
                                         All glob(7) patterns like *,?,[a-z] are supported
                                         plus additional pattern {1-20} which matches
                                         a sequence of numbers: 1,2,3,...,19,20
        -n, --dry-run                    do not change anything, just print commands to be invoked
        -v, --verbose                    increase verbosity
        -c, --clones N                   clone: make N clones
        -s, --snapshot MODE              clone: use LAST shapshot or make NEW
        -H, --headless                   start: start VM in headless mode
        -h, --help                       show this message
