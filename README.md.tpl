vbox-ng    [![Build Status](https://secure.travis-ci.org/zed-0xff/vbox-ng.png)](http://secure.travis-ci.org/zed-0xff/vbox-ng)  [![Dependency Status](https://gemnasium.com/zed-0xff/vbox-ng.png)](https://gemnasium.com/zed-0xff/vbox-ng)
======

Description
-----------
A comfortable way of doing common VirtualBox tasks.

Installation
------------
    gem install vbox-ng

Commandline usage
-----

% vbox -h

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
