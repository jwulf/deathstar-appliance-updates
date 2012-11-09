#!/bin/bash
# This is the plain vanilla installer file for the GA appliance

echo
echo ===========================================================================
echo 
echo ================= Death Star Virtual Appliance Installer ==================
echo 
echo ===========================================================================
echo 
echo "Thank you for purchasing a Friendly Robotics Death Star Virtual Appliance." 
echo "The Death Star is a friendly robotic system that will help you with all "
echo "your topic-based authoring needs."
echo 
echo "Our team of friendly robotic installers will now install your purchase."
echo


NAME="Death_Star"
MAC="00:16:3e:77:e2:ed"
IPADDR="192.168.200.1"
NETWORK_NAME="deathstar"
FQN="${NETWORK_NAME}.local"
VM_FILE_NAME="deathstar-virtual-appliance-sda.raw"
VM_FILE_URL="http://d1nolx37rkohbv.cloudfront.net/deathstar-virtual-appliance-sda.raw"

# rpm dependencies
# virt-manager qemu-kvm

EXISTING=`virsh list --all | grep ${NAME}`

if [ ! -z "${EXISTING}" ]; then
  echo "The virtual machine '${NAME}' already exists in Virtual Machine Manager."
  exit 1
fi

# Download the vmimage
# curl supports resume with "-C -" 
echo
echo ===========================================================================
echo ================================ Step One =================================
echo =================================DOWNLOAD==================================
echo ===========================================================================
echo 
echo Downloading the Death Star Virtual Appliance image...
echo The image file is ~3.5GB in size, and will download from your nearest Amazon CloudFront edge location
echo 

curl -C - -L -O ${VM_FILE_URL}


# mkdir in /opt/deathstar
echo
echo ===========================================================================
echo ================================ Step Two =================================
echo =================================INSTALL===================================
echo ===========================================================================
echo
echo "Performing installation. This may prompt for your password."
if [ ! -z /opt/deathstar ]; then
  sudo mkdir /opt/deathstar;
fi


# Copy vmimage to /opt/deathstar
sudo mv ${VM_FILE_NAME} /opt/deathstar/
cd /opt/deathstar

# Now check if the network is already defined
SUCCESS=0
sudo virsh net-list > /tmp/net-list

grep -q "${NETWORK_NAME}" /tmp/net-list  # -q is for quiet. Shhh...

# Grep's return error code can then be checked. No error=success
if [ $? -ne $SUCCESS ]
then
  # If the network wasn't found, create it 
  # Define network example.com with only one IP available, which will be assigned to
  # ${NAME}.example.com. This network config is what provides for the rhevm server
  # having valid forward and reverse lookups.
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
SUCCESS=0                      # All good programmers use Constants
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

echo "Installing the Death Star to your Hypervisor"
echo
# Now we install the virtual appliance
sudo virt-install -n ${NAME} --import --disk deathstar-virtual-appliance-sda.raw --arch=i686 --os-variant=fedora17 --ram 512 --force --mac 00:16:3e:77:e2:ed --network network:${NETWORK_NAME} --autostart --noautoconsole --quiet
echo
echo "Warming up the lasers...."

sleep 30
echo
echo "This battlestation is now fully operational. Open your web browser to http://tinyurl.com/start-deathstar. May the Force Be with You."

xdg-open http://tinyurl.com/start-deathstar

