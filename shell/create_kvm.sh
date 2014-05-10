#!/bin/bash

export PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin"

dateTime=$(date +%Y%m%d%H%M%S)
tmpDiskFile="/troodon/KVM/Templete/CentOS62.raw"
vmDir="/troodon/KVM"
test -d $vmDir || mkdir -p $vmDir

help() {
	cat >> /dev/stdout <<EOF
Usage: $(basename $0) vmname vcpu memory ip [TempleteDiskFile] | -h
Example: ./$(basename $0) vmname=CentOS vcpu=4 memory=6G ip=192.168.10.10 diskfile=CentOS.img
Example: ./$(basename $0) vmname=CentOS vcpu=2 memory=512M ip=10.10.10.1
Example: ./$(basename $0) -h     //print help infomations
EOF
}

error() {
	echo -e "input parameter error: $1 \n please try again!"
}

if [[ "$#" -eq 0 || "$1" == "-h" ]]; then
	help
	exit 0
fi

for line in $@
    do
	case $line in
	vmname*)
		vmName=$(echo $line | awk -F "=" '{print $2}')
		;;
	vcpu*)
		vCpu=$(echo $line | awk -F "=" '{print $2}')
		if ! echo $vCpu | grep '^[0-9]$' > /dev/null; then
			error $line
			help
			exit 1
		fi
		;;
	memory*)
		memTmp=$(echo $line | awk -F "=" '{print $2}')
		memNum=$(echo ${memTmp:0:${#memTmp}-1})
		memUnit=$(echo ${memTmp:0-1} | tr '[a-z]' '[A-Z]')
		if ! echo $memNum | grep '[0-9]' > /dev/null; then
			error $line
			help
			exit 1
		fi
		if [[ "$memUnit" != "G" && "$memUnit" != "M" && "$memUnit" != "K" ]]; then
			error $line
			help
			exit 1
		fi
		;;
	diskfile*)
		diskFile=$(echo $line | awk -F "=" '{print $2}')
		if [ ! -f "$diskFile" ]; then
			error $line
			help
			exit 1
		fi
		;;
	ip*)
		vmIp=$(echo $line | awk -F "=" '{print $2}')
		if ! echo $vmIp | grep '[0-9]\{1,3\}\(\.[0-9]\{1,3\}\)\{3\}' > /dev/null; then
			error $line
			help
			exit 1
		fi
		;;
		
	*)
		error $line
		help
		exit 1
		;;
	esac
done		

if [ -z "$vmName" ] || [ -z "$vCpu" ] || [ -z "$memNum" ] || [ -z "$vmIp" ];
    then
	echo -e "input parameter incomplete: $@"
	help
	exit 1
fi

if [ -z "$diskFile" ]; then
	echo -e "not assign Templete diskfile, use default Templete diskfile: $tmpDiskFile "
	diskFile=$tmpDiskFile
fi

create_config() {
memUnit="$memUnit"iB
cat > $vmDir/$vmName/$vmName.xml <<EOF
<domain type='kvm'>
  <name>$vmName</name>
  <uuid>$vmUuid</uuid>
  <description>CentOS 6.0 (64-bit)</description>
  <memory unit='$memUnit'>$memNum</memory>
  <currentMemory unit='$memUnit'>$memNum</currentMemory>
  <vcpu placement='static'>$vCpu</vcpu>
  <os>
    <type arch='x86_64' machine='rhel6.2.0'>hvm</type>
    <boot dev='cdrom'/>
    <boot dev='hd'/>
    <bootmenu enable='yes'/>
  </os>
  <features>
    <acpi/>
    <apic/>
    <pae/>
  </features>
  <clock offset='localtime'>
    <timer name='rtc' tickpolicy='catchup'/>
  </clock>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <devices>
    <emulator>/usr/libexec/qemu-kvm</emulator>
    <disk type='file' device='disk'>
      <driver name='qemu' type='raw' cache='none'/>
      <source file='$vmDir/$vmName/$vmName.raw'/>
      <target dev='vda' bus='virtio'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x04' function='0x0'/>
    </disk>
    <disk type='file' device='cdrom'>
      <driver name='qemu' type='raw' cache='none'/>
      <target dev='hdc' bus='ide'/>
      <readonly/>
      <address type='drive' controller='0' bus='1' target='0' unit='0'/>
    </disk>
    <controller type='ide' index='0'>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x01' function='0x1'/>
    </controller>
    <interface type='bridge'>
      <mac address='$vmMac'/>
      <source bridge='br0'/>
      <model type='virtio'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x03' function='0x0'/>
    </interface>
    <serial type='pty'>
      <target port='0'/>
    </serial>
    <console type='pty'>
      <target type='serial' port='0'/>
    </console>
    <input type='tablet' bus='usb'/>
    <input type='mouse' bus='ps2'/>
    <graphics type='vnc' port='-1' autoport='yes' listen='0.0.0.0'/>
    <video>
      <model type='cirrus' vram='9216' heads='1'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x0'/>
    </video>
    <memballoon model='virtio'>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x05' function='0x0'/>
    </memballoon>
  </devices>
</domain>
EOF
}

create_mac() {
test -f /tmp/mac.py && rm -f /tmp/mac.py
cat > /tmp/mac.py <<EOF
#!/usr/bin/python
# macgen.py script to generate a MAC address for Red Hat Virtualization guests
#
import random
#
def randomMAC():
        mac = [ 0x54, 0x52, 0x00,
                random.randint(0x00, 0x7f),
                random.randint(0x00, 0xff),
                random.randint(0x00, 0xff) ]
        return ':'.join(map(lambda x: "%02x" % x, mac))
#
print randomMAC()
EOF
vmMac=$(python /tmp/mac.py)
}

create_uuid() {
vmUuid=$(uuidgen)
}

define_kvm() {
virsh define $vmDir/$vmName/$vmName.xml
if [ $? -ne 0 ]; then
	echo -e "virsh define $vmName.xml error!"
	exit 1
fi
virsh start $vmName
if [ $? -ne 0 ]; then
	echo -e "virsh start $vmName error!"
	exit 1
fi
virsh list
vncPort=$(virsh vncdisplay $vmName)
vncIp=$(ifconfig br0 | awk '/inet addr/{print $2}' | awk -F ":" '{print $2}')
echo -e "VNC IP and Port is: $vncIp$vncPort"
}

modify_disk() {
vmHostName=$(echo $vmIp | awk -F "." '{print "YN-" $3 "-" $4}')
vmIpPri=192.168.$(echo $vmIp | awk -F "." '{print $3 "." $4}')
sectorSize=$(parted $vmDir/$vmName/$vmName.raw unit s print | awk '/Sector size/{print $4}' | awk -F "B" '{print $1}')
sst=$(parted $vmDir/$vmName/$vmName.raw unit s print | awk '/ 1  /{print $2}')
startSector=${sst:0:${#sst}-1}
offSet=$(($startSector*$sectorSize))
mount -o loop,offset=$offSet $vmDir/$vmName/$vmName.raw /mnt/
if [ $? -ne 0 ]; then
	echo -e "mount $vmDir/$vmName/$vmName.raw failed! "
	exit 1
fi
tmpHost="/mnt/etc/sysconfig/network"
tmpIp1="/mnt/etc/sysconfig/network-scripts/ifcfg-eth0"
tmpIp2="/mnt/etc/sysconfig/network-scripts/ifcfg-eth0:1"
tmpZabbix="/mnt/etc/zabbix/zabbix_agentd.conf"
sed -i "s/oriHost/$vmHostName/g" $tmpHost
sed -i "s/IPADDR=oriIpAddr/IPADDR=$vmIp/g" $tmpIp1
sed -i "s/IPADDR=oriIpAddr/IPADDR=$vmIpPri/g" $tmpIp2
sed -i "s/Hostname=oriIpAddr/Hostname=$vmIp/g" $tmpZabbix
umount /mnt
}

dots() {
sec=$1
while true
    do
	echo -e ".\c"
	sleep $sec
done
}

test -d $vmDir/$vmName || mkdir -p $vmDir/$vmName
if [ -f "$vmDir/$vmName/$vmName.xml" ]; then
	mv $vmDir/$vmName/$vmName.xml $vmDir/$vmName/$vmName.xml.$dateTime
	echo -e "$vmDir/$vmName/$vmName.xml exist, rename $vmDir/$vmName/$vmName.xml.$dateTime "
fi
echo -e "create virtual machine config file: $vmDir/$vmName/$vmName.xml ..."
create_mac
create_uuid
create_config
if [ ! -f "$diskFile" ]; then
	echo -e "$diskFile not found, Please try again!"
	exit 1
fi
if [ -f "$vmDir/$vmName/$vmName.raw" ]; then
	mv $vmDir/$vmName/$vmName.raw $vmDir/$vmName/$vmName.raw.$dateTime
	echo -e "$vmDir/$vmName/$vmName.raw exist, rename $vmDir/$vmName/$vmName.raw.$dateTime "
fi
echo -e "create virtual machine disk file: $vmDir/$vmName/$vmName.raw ..."
dots 3 &
bgPid=$!
cp $diskFile $vmDir/$vmName/$vmName.raw
kill $bgPid
echo
echo -e "modify virtual machine IP and Hostname..."
modify_disk
echo -e "define virtual machine ..."
define_kvm
echo -e "create KVM virtual machine:$vmName finish! \n"

