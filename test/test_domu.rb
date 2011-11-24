require 'lib/domraider.rb'
domu = Domraider::DomU.new
domu.mem = '512'
domu.maxmem = '1024'
domu.vcpus = 2
domu.template = '/var/lib/domraider/templates/sl5_x86_64/sl52-x86_64_vanilla_v027.tar.bz2'

#
# DEFINE BLOCK DEVICES
#
# only one of this at a time ATM

# add a sparse block device (sda1 default if not specified) from sparse
#bd = Domraider::BlockDevice.new_sparse('/mnt/drtest-sparse.image', 3096)

# add a LV block device (sda1 default if not specified) from sparse
#bd = Domraider::BlockDevice.new_lv('localvg', 'drtest_lv', 3096)

# add a RAW block device (sda1 default if not specified) from sparse
bd = Domraider::BlockDevice.new_raw('/dev/localvg/drtest-raw')

# create the block device
bd.create
# this is the block device to host de template
domu.root_bd = bd
domu.block_devices << bd

#
# DEFINE VIFS
#
vif = Domraider::Vif.new(:bridge => 'eth0')
domu.network_devices << vif


# this is the default
#domu.on_reboot = 'restart'
#domu.on_crash = 'restart'

# create the domu (xm create)
puts domu.create
