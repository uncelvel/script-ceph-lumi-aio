#!/bin/bash

# STEP 1: Setup host
hostname_conf(){
    hostnamectl set-hostname cephaio
}

pre_setup_install(){
    yum install sshpass -y
}

## setup ip interface
ip_conf(){
    var=$(echo $config_network_interface | tr " " "\n")
    for x in $var
    do
        echo "Setup IP $x"            
        temp_ip=config_network_"$x"_ip
        var_ip=${!temp_ip}
        #echo $var_ip       
        if [ ! -z $var_ip ]; then
            nmcli c modify $x ipv4.addresses $var_ip
        fi

        temp_gateway=config_network_"$x"_gateway
        var_gw=${!temp_gateway} 
        #echo $var_gw
        if [ ! -z $var_gw ]; then
            nmcli c modify $x ipv4.gateway $var_gw
        fi

        temp_dns=config_network_"$x"_dns
        var_dns=${!temp_dns} 
        #echo $var_dns
        if [ ! -z $var_dns ]; then
            nmcli c modify $x ipv4.dns $var_dns
        fi

        nmcli c modify $x ipv4.method manual
        nmcli con mod $x connection.autoconnect yes
    done    

    # echo "Setup IP ens160"
    # nmcli c modify ens160 ipv4.addresses 172.16.2.204/24
    # nmcli c modify ens160 ipv4.gateway 172.16.10.1
    # nmcli c modify ens160 ipv4.dns 8.8.8.8
    # nmcli c modify ens160 ipv4.method manual
    # nmcli con mod ens160 connection.autoconnect yes

    # echo "Setup IP ens192"
    # nmcli c modify ens192 ipv4.addresses 10.0.10.1/24
    # nmcli c modify ens192 ipv4.method manual
    # nmcli con mod ens192 connection.autoconnect yes

    service network restart
}

## setup selinux
selinux_conf(){
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
}

## setup ntp (chuyen sang chouny)
ntp_setup(){
    yum install -y ntp ntpdate ntp-doc
    ntpdate 0.us.pool.ntp.org
    hwclock --systohc
    systemctl enable ntpd.service
    systemctl start ntpd.service
}

host_file_conf(){
    ./tool/manage-etc-hosts.sh cephaio 172.16.4.204
    # echo "setup host file"
    # echo 172.16.2.204 cephaio >> /etc/hosts
}

user_cephdeploy_setup(){
    echo "setup user Ceph Deploy"
    useradd -d /home/$config_ceph_userceph -m $config_ceph_userceph
    echo $config_ceph_password | passwd $config_ceph_userceph --stdin
    echo "$config_ceph_userceph ALL = (root) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/cephuser
    chmod 0440 /etc/sudoers.d/$config_ceph_userceph
    sed -i s'/Defaults requiretty/#Defaults requiretty'/g /etc/sudoers
}

# STEP 2: setup ssh server
ssh_key_conf(){
echo -e "\n" | ssh-keygen -t rsa -N ""

cat > ~/.ssh/config <<EOF
Host cephaio
    Hostname cephaio
    User cephuser
EOF

chmod 644 ~/.ssh/config

echo $'\n'StrictHostKeyChecking no >> ~/.ssh/config
echo $'\n'UserKnownHostsFile=/dev/null >> ~/.ssh/config
echo $'\n'LogLevel QUIET >> ~/.ssh/config

sshpass -p "$config_root_password" ssh-copy-id -o StrictHostKeyChecking=no root@cephaio
}

# STEP 3: setup firewalld
firewalld_conf(){
    systemctl stop firewalld
    systemctl disable firewalld
}

# STEP 4: setup ceph cluster
pre_ceph_install(){
    yum install python-setuptools -y
    yum -y install epel-release
    yum install python-virtualenv -y
    yum install git -y
}

ceph_repo_conf(){
    cat config/ceph.repo > /etc/yum.repos.d/ceph.repo   
    yum update -y 
}

ceph_deploy_install(){
    git clone https://github.com/ceph/ceph-deploy.git
    cd ceph-deploy/
    ./bootstrap
    cp virtualenv/bin/ceph-deploy /usr/bin/
}

ceph_setup(){
    cd 
    mkdir cluster
    cd cluster/
}

ceph_lumi_install(){
    ceph-deploy new cephaio
    ceph-deploy install --release luminous cephaio
}

ceph_mon_setup(){
    ceph-deploy mon create-initial
}


# MAIN

pre(){
    hostname_conf

    pre_setup_install

    ip_conf

    selinux_conf

    ntp_setup

    host_file_conf

    user_cephdeploy_setup
}

setup_ssh_firewall(){
    ssh_key_conf

    firewalld_conf     
}

setup_ceph(){
    pre_ceph_install

    ceph_repo_conf

    ceph_deploy_install

    ceph_setup

    ceph_lumi_install

    ceph_mon_setup
}


