#!/bin/bash
# @author       Chris Iverach-Brereton <civerachb@clearpathrobotics.com>
# @author       David Niewinski <dniewinski@clearpathrobotics.com>
# @description  Creates a backup of a single robot's configuration after integration

# the username we use to SSH into the remote host
USERNAME=administrator

# the password associated with the user defined above
PASSWORD=clearpath

# the version of _this_ script
VERSION=2.0.1

if [ $# -ge 2 ]
then
  CUSTOMER=$1
  HOST=$2

  if [[ $HOST == *"@"* ]];
  then
    echo "Overriding default username"
    USERNAME=${HOST%@*}
    HOST=${HOST#*@}

    echo "Username: $USERNAME"
    echo "Host: $HOST"
  fi

    if [ $# == 3 ];
    then
      echo "Overriding default password"
      PASSWORD=$3

      echo "Password: $PASSWORD"
    fi

  echo "===== Starting Clearpath Robotics Robot Backup v$VERSION ====="
  echo "Creating backup for $USER@$HOST"

  echo "Creating Directory <" $PWD"/"$CUSTOMER ">"
  mkdir "$CUSTOMER"
  cd "$CUSTOMER"

  ############################ BACKUP METADATA ###############################
  echo "Querying ROS Distro"
  # NOTE: we cannot reliably run rosversion -d, as on some systems a non-interactive ssh terminal
  # will _not_ source .bashrc, which in turn won't source /opt/ros/[distro]/setup.bash
  # therefore we check the /opt/ros folder for the appropriate distro folder and use that
  # if there's more than one folder we pick the last one
  ROSDISTRO=$(echo "ls -rt /opt/ros | tail -1" | ssh -T $USERNAME@$HOST | tail -1)
  echo "ROS distro is $ROSDISTRO"
  echo "$ROSDISTRO" > ./ROS_DISTRO

  # create a command we can run _before_ any SSH commands that require ROS commands
  # this should be prepended to any commands (i.e. $SSH_SOURCE_CMD && <other stuff to run>)
  SSH_SOURCE_CMD="source /opt/ros/$ROSDISTRO/setup.bash"

  # record the version of this script so we can make sure the restore script is the same version
  echo "$VERSION" > ./BKUP_VERSION

  ############################ BACKUP #############################

  echo "Copying udev rules"
  scp -r $USERNAME@$HOST:/etc/udev/rules.d .

  echo "Copying Network Setup"
  scp $USERNAME@$HOST:/etc/network/interfaces .
  scp $USERNAME@$HOST:/etc/hostname .
  scp $USERNAME@$HOST:/etc/hosts .

  echo "Copying IPTables"
  scp -r $USERNAME@$HOST:/etc/iptables .

  echo "Copying Bringup"
  scp $USERNAME@$HOST:/etc/ros/setup.bash .
  scp -r $USERNAME@$HOST:/etc/ros/$ROSDISTRO/ros.d .
  mkdir -p usr/sbin
  scp -r $USERNAME@$HOST:/usr/sbin/*start usr/sbin
  scp -r $USERNAME@$HOST:/usr/sbin/*stop usr/sbin

  echo "Copying RosDep sources"
  scp -r $USERNAME@$HOST:/etc/ros/rosdep/ .

  echo "Copying rclocal"
  scp -r $USERNAME@$HOST:/etc/rc.local .

  echo "Copying pip packages"
  # strip the first 2 lines from pip list output; they're headers we don't need!
  echo "$SSH_SOURCE_CMD && pip list | tail -n +3 > /tmp/pip.list" | ssh -T $USERNAME@$HOST
  scp -r $USERNAME@$HOST:/tmp/pip.list .
  echo "rm /tmp/pip.list" | ssh -T $USERNAME@$HOST

  echo "Copying Systemd"
  scp -r $USERNAME@$HOST:/etc/systemd/system .

  echo "Copying user groups"
  echo "groups" | ssh -T $USERNAME@$HOST | tail -1 > groups

  echo "Copying APT sources & packages"
  scp -r $USERNAME@$HOST:/etc/apt/sources.list.d .
  echo "Copying APT sources & packages2"
  echo "apt-mark showmanual > /tmp/installed_pkgs.list" | ssh -T $USERNAME@$HOST
  scp -r $USERNAME@$HOST:/tmp/installed_pkgs.list .
  echo "Copying APT sources & packages3"
  echo "rm /tmp/installed_pkgs.list" | ssh -T $USERNAME@$HOST

  echo "Cleaning up bag"
  echo "rm auto_backup*.bag" | ssh -T $USERNAME@$HOST

  echo "Copying Home Folder"
  scp -r $USERNAME@$HOST:~ .

  cd ..
  echo "Done Transfer"
  #################################################################

  ######################## REMOVE BIN+DEV #########################
  #echo "Cleaning"
  rm -rf $1/administrator/catkin_ws/build/
  rm -rf $1/administrator/catkin_ws/devel/
  #echo "Done"
  #################################################################

  ########################## COMPRESSION ##########################
  echo "Compressing"
  tar -zcf $CUSTOMER.tar.gz $CUSTOMER
  echo "Done Compression"
  #################################################################

  ########################### CLEANING ############################
  echo "Cleaning Up"
  rm -rf $CUSTOMER
  echo "Done Cleaning"
  #################################################################

  echo "======= Done Clearpath Robotics Robot Backup v$VERSION ======="
else
  echo "USAGE: bash backup.sh customer_name [user@]hostname [password]"
fi
