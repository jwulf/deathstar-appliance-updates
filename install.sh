#!/bin/bash

# This script installs the Death Star virtual appliance from a USB key or over the network
# script version: 0.90.1
# license: GPL

# Code:
# Joshua Wulf jwulf@redhat.com
# Steve Gordon sgordon@redhat.com

# Testing: 
# Mansoureh Targhi mtarghi@redhat.com
 
# Currently supported OSs:
#
# RHEL 6
# Fedora 16, 17

# Potential for future support:
#
# Ubuntu with KVM
# Mac OS X with VirtualBox

############ CHANGELOG ##############
#21 Nov 12 version 0.90.1
#  Joshua Wulf <jwulf@redhat.com>
#  - Moved Startup URL to variable to facilitate single sourcing of public
#    and Red Hat internal versions of the script
############ /CHANGELOG ##############

NAME="Death_Star"
MAC="00:16:3e:77:e2:ed"
IPADDR="192.168.200.1"
NETWORK_NAME="deathstar"
FQN="${NETWORK_NAME}.local"
VM_FILE_NAME="deathstar-virtual-appliance-sda.raw"
VM_INSTALL_DIR="/opt/deathstar"
VM_INSTALLED="${VM_INSTALL_DIR}/${VM_FILE_NAME}"
VM_FILE_URL="http://d1nolx37rkohbv.cloudfront.net/deathstar-virtual-appliance-sda.raw"
STARTUP_URL="http://www.tinyurl.com/start-deathstar"

clear
echo
echo
echo
echo
echo ===========================================================================
echo ========================== Friendly Robotics ==============================
echo ===================== Death Star Virtual Appliance  =======================
echo ============================= Installer ===================================
echo ===========================================================================
echo 
echo "Thank you for purchasing a Friendly Robotics Death Star Virtual Appliance." 
echo
echo "The Death Star is a friendly robotic system to help you with all "
echo "your topic-based authoring needs."
echo 
echo "Our team of friendly robotic installers will now install your purchase."
echo
echo
echo ===========================================================================
echo ================================ Step Zero ================================
echo ================================PREPARATION================================
echo ===========================================================================
echo
echo "Please stand by while we check the virtualization plumbing...."
echo

# Check that dependencies are installed
# virt-manager qemu-kvm libvirt

trigger=0 # Used to trigger a module reinsertion if needed

# Check for virt-manager
rpm -q virt-manager > /dev/null
if [ $? == 1 ]; then
	echo "Installing virt-manager..."
	sudo yum install virt-manager -y --nogpgcheck --quiet
	trigger=1
else
	# The possibility of a corrupted RPM DB is not handled
	echo "Good: virt-manager already present"
fi

# Check for qemu-kvm
rpm -q qemu-kvm > /dev/null
if [ $? == 1 ]; then
	echo "Installing qemu-kvm..."
	sudo yum install qemu-kvm -y --nogpgcheck --quiet
	trigger=1
else
	echo "Good: qemu-kvm already present"
fi

# Check for libvirt
rpm -q libvirt > /dev/null
if [ $? == 1 ]; then
	echo "Installing libvirt..."
	sudo yum install libvirt -y --nogpgcheck --quiet
	trigger=1
else
	echo "Good: libvirt already present"
fi

if [ trigger == 1 ]; then
# If we installed virt packages, then
# make sure the right udev facls are set:
# ref: https://bugs.launchpad.net/ubuntu/+source/qemu-kvm/+bug/1057024
	sudo modprobe -r kvm_intel
	sudo modprobe kvm_intel
fi

# Check if the libvirt service is running; if not, start it
SERVICE_RUNNING=0 # Exit value of "service libvirtd status" when running
sudo service libvirtd status > /dev/null
if [ $? -ne ${SERVICE_RUNNING} ]; then
	sudo service libvirtd start
fi

echo

# Check for the Virtual Machine 
EXISTING=`sudo virsh list --all | grep ${NAME}`
if [ ! -z "${EXISTING}" ]; then
  echo "The virtual machine '${NAME}' already exists in Virtual Machine Manager."
  echo "If you want to reinstall, use Virtual Machine Manager to delete the existing machine, then retry."
  exit 1
fi

# Check if we've already copied an image locally - don't download it again!
if [ -f ${VM_INSTALLED} ]; then
	echo "Using the appliance found at ${VM_INSTALLED}."
	echo "(If that's not what you wanted, delete that file and try again.)"
fi

if [ ! -f ${VM_INSTALLED} ]; then
	echo
	echo ===========================================================================
	echo ================================ Step One =================================
	echo =================================DOWNLOAD==================================
	echo ===========================================================================
	echo
	echo "Creating the download location. This may prompt for your password."
	if [ ! -d ${VM_INSTALL_DIR} ]; then
	  sudo mkdir ${VM_INSTALL_DIR}
	fi

	# Running off a USB stick; image in the current working directory
	if [ -f ${VM_FILE_NAME} ]; then
		echo "(I think I'm running on a USB stick here...)"
		echo "Copying the Death Star Virtual Applicance image. Please wait, it's a 3.5GB file..."	
		sudo cp ${VM_FILE_NAME} ${VM_INSTALL_DIR}
	fi
	
	# Not running off a USB stick, download the image
	if [ ! -f ${VM_FILE_NAME} ]; then
		echo "Downloading the Death Star Virtual Appliance image."
		echo 
		echo "It's ~3.5GB, and coming from your nearest Amazon CloudFront edge location"
		echo 
		# Download the vmimage
		# curl supports resume with "-C -" 
		echo "Downloading the image"
		curl -C - -L -O ${VM_FILE_URL}
	fi
fi

cd ${VM_INSTALL_DIR}

echo
echo ===========================================================================
echo ================================ Step Two =================================
echo =================================INSTALL===================================
echo ===========================================================================
echo
echo "Performing installation. This may prompt for your password."

# Check if the virtual network is already defined
SUCCESS=0
sudo virsh net-list > /tmp/net-list

grep -q "${NETWORK_NAME}" /tmp/net-list  # -q is for quiet. Shhh...

# Grep's return error code can then be checked. No error=success
if [ $? -ne $SUCCESS ]
then
  # If the network wasn't found, create it 
  # Define network ${NAME}with only one IP available, which will be assigned to our appliance
   echo "<network>
    <name>${NETWORK_NAME}</name>
    <bridge name='virbr10' />
    <forward mode='nat' />
    <domain name='local' />
    <dns>
      <host ip='${IPADDR}'>
        <hostname>${FQN}</hostname>
      </host>
    </dns> 
    <ip address='192.168.200.254' netmask='255.255.255.0'>
      <dhcp>
        <range start='192.168.200.1' end='192.168.200.254' />
        <host mac='${MAC}' name='${FQN}' ip='192.168.200.1' />
      </dhcp>
    </ip>
  </network>" > /tmp/deathstar-network.xml

sudo virsh net-define /tmp/deathstar-network.xml
sudo virsh net-autostart deathstar
sudo virsh net-start deathstar
fi

# Add an entry to the /etc/hosts file
# This allows an address (such as "deathstar.local") to work in a web browser

SUCCESS=0             
hostline="${IPADDR} ${FQN}"
filename=/etc/hosts

# Determine if the line already exists in /etc/hosts
grep -q "$hostline" "$filename"  # -q is for quiet. Shhh...

# Grep's return error code can then be checked. No error=success
if [ $? -ne $SUCCESS ]
then
  # If the line wasn't found, add it using an echo append >>
sudo echo "$hostline" >> "$filename"
  echo "Adding hosts entry"
  echo
fi

echo "Installing Virtual Appliance"
echo
# Now we install the virtual appliance
sudo virt-install -n ${NAME} --import --disk ${VM_INSTALLED} --arch=i686 --os-variant=fedora17 --ram 512 --force --mac 00:16:3e:77:e2:ed --network network:${NETWORK_NAME} --autostart --noautoconsole --quiet

progressmsg="Warming up the lasers...."

for i in {1..20}
	do
	echo -ne "${progressmsg}\r"
	sleep 1	
	progressmsg="${progressmsg}."
	done
echo

echo "This battlestation is now fully operational. Open your web browser to ${STARTUP_URL}. May the Force Be with You."

# Redirect output to /dev/null for Firefox spam bug: https://bugzilla.mozilla.org/show_bug.cgi?id=786860
# send xdg-open to background using "&" so that the script exits

xdg-open ${STARTUP_URL} > /dev/null &

