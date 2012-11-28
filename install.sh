#!/bin/bash

# This script installs the Death Star virtual appliance from a USB key or over the network
# script version: 0.93
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
# Ubuntu with KVM
# Mac OS X with VirtualBox

# Future support:
#
# Windows with VirtualBox - will require a different installer

############ CHANGELOG ##############
# 21 Nov 12 
# version 0.90.1
#  Joshua Wulf <jwulf@redhat.com>
#  - Moved Startup URL to variable to facilitate single sourcing of public
#    and Red Hat internal versions of the script
#
# 26 Nov 12
# version 0.90.2
#  Joshua Wulf <jwulf@redhat.com>
#  - Added code to clean up temporary files
#
# version 0.91
#  Joshua Wulf <jwulf@redhat.com>
#  - Added support for Mac OS X with Oracle VirtualBox
#
# versin 0.92
#  Joshua Wulf
#  - Added support for Ubuntu with KVM
#
# version 0.93
#  Joshua Wulf <jwulf@redhat.com>
#  - VM Image is now tar gzipped - it will be decompressed after download
#
############ /CHANGELOG ##############

UNAME=`uname`

if [ "$UNAME" != "Linux" -a "$UNAME" != "Darwin" ] ; then
    echo "Sorry, this OS is not supported yet. If you want to write an installer, fork www.github.com/jwulf/deathstar-appliance-updates."
    exit 1
fi

setCommonSettings () {
    VM_FILE_URL="http://d1nolx37rkohbv.cloudfront.net/deathstar-virtual-appliance-sda.raw.tar.gz"
    VM_ZIP_FILE="deathstar-virtual-appliance-sda.raw.tar.gz"
    STARTUP_URL="http://www.tinyurl.com/start-deathstar"
    VM_FILE_NAME="deathstar-virtual-appliance-sda.raw"
    NETWORK_NAME="deathstar"
    FQN="${NETWORK_NAME}.local"
}
    
setKVMSettings () {
    # Used on RHEL / Fedora / Ubuntu    
    NAME="Death_Star"
    MAC="00:16:3e:77:e2:ed"
    IPADDR="192.168.200.1"
    VM_INSTALL_DIR="/opt/deathstar"
    VM_INSTALLED="${VM_INSTALL_DIR}/${VM_FILE_NAME}"
    KVMSUDO="sudo"
    PKG_NOT_INSTALLED=1
    UBUNTU_SERVICE=libvirt-bin
    REDHAT_SERVICE=libvirtd
}

setVirtualBoxSettings () {
    # Used on Mac OS X
    APPLIANCE_NAME="Death Star Appliance"
    VM_RAW_FILE=$VM_FILE_NAME
    VM_VDI_NAME="deathstar-appliance-sda.vdi"  
    VM_INSTALL_DIR="${HOME}/appliance"
    VM_INSTALLED="${VM_INSTALL_DIR}/${VM_VDI_NAME}"
    IPADDR="192.168.56.25"
    KVMSUDO=""
}

dontRunWithRoot () {    
    if [ `whoami` = 'root' ] ; then    
        echo "Please don't run this as root. I need to create the appliance in your user account."
        echo "The installer will request sudo when it needs it"
        exit 1
    fi
}
    
introMsg () {
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
}

checkPreReqsMacOS () {
    VBOXPRESENCE="/usr/bin/VBoxManage"
    
    echo "Mac OS X system detected."
    echo 
    
    if [ -f $VBOXPRESENCE ]; then
        echo "Good: Oracle VirtualBox detected"
    else
        echo "Is Oracle VirtualBox installed? I couldn't find $VBOXPRESENCE"
        exit 1
    fi
}

checkPreReqsRedHat () {
    echo "Red Hat / Fedora operating system detected."
    echo
    # Check that dependencies are installed

    trigger=0 # Used to trigger a module reinsertion if needed
    
    for dependency in "virt-manager" "qemu-kvm" "libvirt"; do

        rpm -q $dependency > /dev/null
        if [ $? == $PKG_NOT_INSTALLED ]; then
            echo "Installing $dependency..."
            sudo yum install $dependency -y --nogpgcheck --quiet
        	trigger=1
        else
        	# The possibility of a corrupted RPM DB is not handled
        	echo "Good: $dependency already present"
        fi
    done    
        
    if [ trigger == 1 ]; then
    # If we installed virt packages, then
    # make sure the right udev facls are set:
    # ref: https://bugs.launchpad.net/ubuntu/+source/qemu-kvm/+bug/1057024
        sudo rmmod kvm_intel kvm
        sudo modprobe kvm_intel
    fi
    
    # Check if the libvirt service is running; if not, start it
    SERVICE_RUNNING=0 # Exit value of "service libvirtd status" when running
    sudo service libvirtd status > /dev/null
    if [ $? -ne ${SERVICE_RUNNING} ]; then
    	sudo service libvirtd start
    fi  
}

checkPreReqsUbuntu () {
    echo "Debian / Ubuntu operating system detected."
    echo 

  # Check that dependencies are installed

    trigger=0 # Used to trigger a module reinsertion if needed
    
    for dependency in "virt-manager" "virtinst" "bridge-utils" "virt-viewer" "qemu-kvm"; do

        dpkg -s $dependency 1> /dev/null 2> /dev/null
        if [ $? = $PKG_NOT_INSTALLED ]; then
            echo "Installing $dependency..."
            sudo apt-get install $dependency -y  -qq
            trigger=1
        else
        	echo "Good: $dependency already present"
        fi
    done    
        
    if [ trigger = 1 ]; then
    # If we installed virt packages, then
    # make sure the right udev facls are set:
    # ref: https://bugs.launchpad.net/ubuntu/+source/qemu-kvm/+bug/1057024
    	sudo modprobe -r kvm_intel
    	sudo modprobe kvm_intel
    fi
    
    # Check if the libvirt service is running; if not, start it
    SERVICE_RUNNING=0 # Exit value of "service libvirtd status" when running
    sudo service libvirt-bin status > /dev/null
    if [ $? -ne ${SERVICE_RUNNING} ]; then
    	sudo service libvirt-bin start
    fi  
    

}


checkIfVMAlreadyExistsKVM () {
    # Check for the Virtual Machine 
    EXISTING=`sudo virsh list --all | grep ${NAME}`
    if [ ! -z "${EXISTING}" ]; then
        echo
        echo "The virtual machine '${NAME}' already exists in Virtual Machine Manager."
        echo "If you want to reinstall, use Virtual Machine Manager to delete the existing machine, then retry."
        exit 1
    fi
}

checkIfVMAlreadyExistsVirtualBox () {
    VM_EXISTS=0;
    
    VBoxManage showvminfo "$APPLIANCE_NAME" 1> /dev/null 2>/dev/null

    if [ $? -eq $VM_EXISTS ]; then
        echo
        echo "The virtual machine '${APPLIANCE_NAME}' already exists in VirtualBox."
        echo "If you want to reinstall, delete the VM and its associated storage files, then retry"
        exit 1
    fi
}
    
getVMImage () {
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
    	  $KVMSUDO mkdir ${VM_INSTALL_DIR}
    	fi
    
    	# Running off a USB stick; image in the current working directory
    	if [ -f ${VM_ZIP_FILE} ]; then
    		echo "(I think I'm running from a USB stick here...)"
    		echo "Copying the Death Star Virtual Appliance image. Please wait, it's a 1.2GB file..."	
    		$KVMSUDO cp ${VM_ZIP_FILE} ${VM_INSTALL_DIR}
            decompressImage
    	fi
    	
    	# Not running off a USB stick, download the image
    	if [ ! -f ${VM_FILE_NAME} ]; then
    		echo "Downloading the Death Star Virtual Appliance image."
    		echo 
    		echo "It's ~1.2GB, and coming from your nearest Amazon CloudFront edge location"
    		echo 
    		# Download the vmimage
    		# curl supports resume with "-C -" 
    		echo "Downloading the image"
    		curl -C - -L -O ${VM_FILE_URL}
            decompressImage
    	fi
    fi    
}

decompressImage () {
    echo "Decompressing image..."
    tar -zxf ${VM_ZIP_FILE}
    if [ -f ${VM_FILE_NAME} ]; then
        rm ${VM_ZIP_FILE}
    fi  
}

installMsg () {
    echo
    echo ===========================================================================
    echo ================================ Step Two =================================
    echo =================================INSTALL===================================
    echo ===========================================================================
    echo
    echo "Performing installation. This may prompt for your password."   
}
    
createNetworkKVM () {
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
        
        # cleanup 
        rm /tmp/deathstar-network.xml
        sudo rm /tmp/net-list
    fi
}

createHostsEntry () {
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
}

installVM_KVM () {
    echo "Installing Virtual Appliance"
    echo
    # Now we install the virtual appliance
    sudo virt-install -n ${NAME} --import --disk ${VM_INSTALLED} --arch=i686 --os-variant=fedora17 --ram 512 --force --mac 00:16:3e:77:e2:ed --network network:${NETWORK_NAME} --autostart --noautoconsole --quiet
}

installVM_VirtualBox () {
    # Create and configure the VirtualBox VM
    VBoxManage createvm --name "${APPLIANCE_NAME}" --ostype "RedHat" --register
    VBoxManage modifyvm "${APPLIANCE_NAME}" --memory "512"
    VBoxManage storagectl "${APPLIANCE_NAME}" --add sata --bootable on --name "SATA"
    VBoxManage storageattach "${APPLIANCE_NAME}" --storagectl "SATA" --port 0 --device 0 --type hdd --medium $VM_INSTALLED
    # Host-only adapter for communication with host
    VBoxManage modifyvm "${APPLIANCE_NAME}" --nic1 hostonly 
    VBoxManage modifyvm "${APPLIANCE_NAME}" --hostonlyadapter1 "vboxnet0"
    # NAT adapter for communication with external world
    VBoxManage modifyvm "Death Star Appliance" --nic2 nat
    VBoxManage modifyvm "${APPLIANCE_NAME}" --autostart-enabled on
    
    # Start the VM
    VBoxManage startvm "${APPLIANCE_NAME}" &
}

convertRAW2VDI () {
    if [ ! -f $VM_INSTALLED ]; then
        echo "Converting image to VirtualBox format..."
        VBoxManage convertfromraw $VM_RAW_FILE $VM_INSTALLED --format VDI    
    fi 
    
    # Leave this commented for troubleshooting - can do multiple runs with the
    # same image
#    if [ -f $VM_INSTALLED ]; then
#        rm -f $VM_RAW_FILE
#    fi
}

warmupMsg () {
    progressmsg="Warming up the lasers...."

    for i in {1..30}
        do
    	echo -ne "${progressmsg}\r"
    	sleep 1	
    	progressmsg="${progressmsg}."
    	done
    echo
    
    echo "This battlestation is now fully operational. Open your web browser to ${STARTUP_URL}. May the Force Be with You."
}

continueOnlyIfDiskImageExists () {
       if [ ! -f $VM_INSTALLED ]; then
            echo "Something went wrong - I can't find the image at $VM_INSTALLED."
            exit 1
        fi
}

openURL_Linux () {
    # Redirect output to /dev/null for Firefox spam bug: https://bugzilla.mozilla.org/show_bug.cgi?id=786860
    # send xdg-open to background using "&" so that the script exits
    
    xdg-open ${STARTUP_URL} > /dev/null &
}

        
if [ "$UNAME" = "Darwin" ] ; then
    ### OSX ###
    
    dontRunWithRoot
    
    setCommonSettings
    setVirtualBoxSettings

    introMsg
    checkPreReqsMacOS
    checkIfVMAlreadyExistsVirtualBox

    getVMImage
    
    installMsg
    convertRAW2VDI
    
    continueOnlyIfDiskImageExists
    
    createHostsEntry
    installVM_VirtualBox
    
    warmupMsg
    #openURL_Mac
    # To do: install service
    # http://mikkel.hoegh.org/blog/2010/12/23/run-virtualbox-boot-mac-os-x/
    # http://developer.apple.com/library/mac/#documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html
    
elif [ "$UNAME" = "Linux" ] ; then
    ### Linux - thus KVM ###

    if [ -f "/etc/debian_version" ] ; then
        ## Debian / Ubuntu ##

        setCommonSettings   
        setKVMSettings
        
        introMsg
        checkPreReqsUbuntu
        checkIfVMAlreadyExistsKVM
        
        getVMImage
        
        continueOnlyIfDiskImageExists
        
        installMsg
        createNetworkKVM
        createHostsEntry
        installVM_KVM
        
        warmupMsg
        openURL_Linux
        
    elif [ -f /etc/redhat-release -o -x /bin/rpm ] ; then
        ## Red Hat / Fedora ##

        setCommonSettings   
        setKVMSettings
        
        introMsg
        checkPreReqsRedHat
        checkIfVMAlreadyExistsKVM
        
        getVMImage
        
        continueOnlyIfDiskImageExists
        
        installMsg
        createNetworkKVM
        createHostsEntry
        installVM_KVM
        
        warmupMsg
        openURL_Linux
    fi
fi
 
