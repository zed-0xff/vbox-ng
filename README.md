vbox-ng    [![Build Status](https://secure.travis-ci.org/zed-0xff/vbox-ng.png)][Continuous Integration] [![Dependency Status](https://gemnasium.com/zed-0xff/vbox-ng.png)][Dependencies]
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
    	vbox [options]                           - list VMs
    	vbox [options] <vm_name>                 - show VM params
    	vbox [options] <vm_name> <param>=<value> - change VM params (name, cpus, usb, etc)
    	vbox [options] <vm_name> <command>       - make some action (start, reset, etc) on VM
    
    COMMANDS:
    	start, pause, resume, reset, poweroff, savestate,
    	acpipowerbutton, acpisleepbutton, clone, delete, show, snapshots
    
    OPTIONS:
    	-g, --[no-]glob                  (default: auto) assume <vm_name> is a wildcard,
    	                                 and run on multiple VMs.
    	                                 All glob(7) patterns like *,?,[a-z] are supported
    	                                 plus additional pattern {1-20} which matches
    	                                 a sequence of numbers: 1,2,3,...,19,20
    	-n, --dry-run                    do not change anything, just print commands to be invoked
    	-v, --verbose                    increase verbosity
    	-c, --clones N                   clone: make N clones
    	-S, --snapshot MODE              clone: use LAST shapshot or make NEW
    	-H, --headless                   start: start VM in headless mode
    	-h, --help                       show this message
    
    EXAMPLES:
    	vbox -v                        - list VMs with memory and dir sizes
    	vbox "d{1-10}" list            - list only VMs named 'd1','d2','d3',...,'d10'
    	vbox "test*" start             - start VMs which name starts with 'test'
    	vbox "v[ace]" cpus=2 acpi=on   - set number of cpus & ACPI on VMs named 'va','vc','ve'
    	vbox d0                        - list all parameters of VM named 'd0'
    	vbox d0 clone -c 10 -S last    - make 10 new linked clones of vm 'd0' using the
    	                                 latest hdd snapshot, if any
    	vbox d0 clone -c 10 -S new     - make ONE new shapshot of VM 'd0' and then make
    	                                 10 new clones linked to this snapshot
    	vbox "tmp?" delete             - try to destroy all VMs which name is 4 letters long
    	                                 and starts with 'tmp'
    	vbox ae340207-f472-4d63-80e7-855fca6808cb
    	                               - list all parameters of VM with this GUID
    	vbox --no-glob "*wtf?!*" rm    - destroy VM which name is '*wtf?!*'

Ruby examples
=============

Clone first VM
-----
``` ruby
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
``` ruby
>> vm2 = VBOX::VM.find 'd14'
>> vm2.start!
[.] $DISPLAY is not set, assuming --headless
Waiting for VM "59d9af2a-4401-4b38-ad74-b5c6c6b45a81" to power on...
VM "59d9af2a-4401-4b38-ad74-b5c6c6b45a81" has been successfully started.
=> true
```

Stop VM and destroy it (delete all its files)
-----
``` ruby
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

Calculate total disk space occupied by all VMs
-----
``` ruby
>> VBOX::VM.all.map(&:dir_size).inject(&:+)
=> 20271
```

Show all VMs sorted by directory size in reverse order
-----
``` ruby
>> VBOX::VM.all.sort_by(&:dir_size).reverse.each{ |vm| printf "%5d %s\n", vm.dir_size, vm.name }
 9175 xp
 5336 rwthCTF2012 vulnbox final
 2962 ubuntu 12.04.1
 2184 d0
  109 u2
   87 u1
```
