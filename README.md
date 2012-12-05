vbox-ng
======

Description
-----------
A comfortable way of doing common VirtualBox tasks.

Installation
------------
    gem install vbox-ng

Commandline usage
-----

    # vbox -h

    USAGE:
    	cli.rb [options]                           - list VMs
    	cli.rb [options] <vm_name>                 - show VM params
    	cli.rb [options] <vm_name> <param>=<value> - change VM params (name, cpus, usb, etc)
    	cli.rb [options] <vm_name> <command>       - make some action (start, reset, etc) on VM
    
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

Ruby examples
=============

Clone first VM
-----
```
# irb
>> require 'vbox'
=> true
>> vm = VBOX::VM.first
=> #<VBOX::VM:0x000000012c5320 @all_vars={}, @uuid="{ae340207-f472-4d63-80e7-855fca6808cb}", @name="d0">
>> vm2 = vm.clone! :snapshot => :last
0%...10%...20%...30%...40%...50%...60%...70%...80%...90%...100%
Machine has been successfully cloned as "d1"
[.] old macaddress1=dec0de000000
[.] new macaddress1=dec0de000001
=> #<VBOX::VM:0x00000001315820 @all_vars={}, @uuid="{59d9af2a-4401-4b38-ad74-b5c6c6b45a81}", @name="d1">
```

Find VM by name and start it
-----
```
>> vm2 = VBOX::VM.find 'd14'
>> vm2.start!
[.] $DISPLAY is not set, assuming --headless
Waiting for VM "59d9af2a-4401-4b38-ad74-b5c6c6b45a81" to power on...
VM "59d9af2a-4401-4b38-ad74-b5c6c6b45a81" has been successfully started.
=> true
```

Stop VM and destroy it (delete all its files)
-----
```
>> vm2 = VBOX::VM.find 'd14'
>> vm2.poweroff!
0%...10%...20%...30%...40%...50%...60%...70%...80%...90%...100%
=> true
>> vm2.destroy!
0%...10%...20%...30%...40%...50%...60%...70%...80%...90%...100%
=> true
>> vm2 = VBOX::VM.find 'd14'
=> nil
```
