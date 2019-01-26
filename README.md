## qemu

Based on

- https://www.gnu.org/software/guix/manual/en/html_node/Running-GuixSD-in-a-VM.html
- https://github.com/cbaines/practical-introduction-to-guix

Grab the latest image from https://alpha.gnu.org/gnu/guix/.

```bash
$ curl -OJN https://alpha.gnu.org/gnu/guix/guixsd-vm-image-0.16.0.x86_64-linux.xz
$ unxz guixsd-vm-image-0.16.0.x86_64-linux.xz
# or this: unxz -k -c guixsd-vm-image-0.16.0.x86_64-linux.xz > guixsd-vm-image-0.16.0.x86_64-linux-2
$ qemu-system-x86_64 -net user -net nic,model=virtio -enable-kvm -m 256 guixsd-vm-image-0.16.0.x86_64-linux
```

Press enter to when see blue menu.

Now inside guixsd, login as root, no password.

```bash
gnu login: root
$ ip link
# looks like this is not needed: ip link set dev eth0 up
# also specifying interface is not needed: dhclient eth0
 dhclient
$ guix pull
No space left on device
$ shutdown
```

Shift+Page up/Page down to scroll.


## Resize partition

```bash
$ qemu-img info guixsd-vm-image-0.16.0.x86_64-linux
image: guixsd-vm-image-0.16.0.x86_64-linux
file format: qcow2
virtual size: 1.2G (1340860416 bytes)
disk size: 1.1G
cluster_size: 65536
Format specific information:
    compat: 1.1
    lazy refcounts: false
    refcount bits: 16
    corrupt: false
$ qemu-img resize guixsd-vm-image-0.16.0.x86_64-linux +10G
# Out of memory when running `guix pull` and qemu with `-m 256`
$ qemu-system-x86_64 -net user -net nic,model=virtio -enable-kvm -m 1024 guixsd-vm-image-0.16.0.x86_64-linux
```

Inside guixsd

```bash
$ fdisk -l
$ fdisk /dev/sda
# remove all paritions, also efi parition which was the second
> d
> n
> p
> Enter, Enter, Enter
# remove ext4 signature
> Y
> w
$ partprobe
$ resize2fs /dev/sda1
# check available space
$ df -H
# check available inodes
$ df -i
# check reserved percentage for root
$ tune2fs -l /dev/sda1 | grep -i reserved
```

- https://askubuntu.com/questions/107228/how-to-resize-virtual-machine-disk
- https://stackoverflow.com/questions/29221066/how-can-i-detect-a-qemu-image
- https://serverfault.com/questions/509468/how-to-extend-an-ext4-partition-and-filesystem/509473#509473
- https://medium.com/@yushulx/how-to-resize-raspbian-image-for-qemu-on-windows-ac0b44075d8f
- https://unix.stackexchange.com/questions/424943/resizing-linux-partition-backwards/425476#425476
- https://serverfault.com/questions/73051/no-space-left-on-device-df-shows-discrepancy/73057#73057

## About partition signature

Each disk and partition has some sort of signature and metadata/magic strings on it. The metadata used by operating system to configure disks or attach drivers and mount disks on your system. You can view such partition-table signatures/metadata/magic strings using the wipefs command. The same command can erase filesystem, raid or partition-table signatures/metadata.

Display or show current signatures

Type the following command:
`$ sudo wipefs /dev/sda`

OR
`$ sudo wipefs /dev/sda1`

https://www.cyberciti.biz/faq/howto-use-wipefs-to-wipe-a-signature-from-disk-on-linux/

## package management

```bash
$ guix package -i wget
$ wget gnu.org
$ cat index.html
```

- https://www.gnu.org/software/guix/manual/en/html_node/Invoking-guix-package.html 
- https://www.gnu.org/software/guix/packages/

## qemu-system-x86_64: warning: host doesn't support requested feature: CPUID.80000001H:ECX.svm [bit 2]


## git

Inside guixsd

```bash
$ guix package -i git
# create public key as described here https://github.com/kisswiki/kisswiki/blob/master/src/github/ssh.md
# as I cannot copy text from qemu, I am using sprunge.us
$ guix package -i curl
$ cat ~/.ssh/github_rsa.pub | curl -F "sprunge=<-" http://sprunge.us
# add to github
$ ssh-T git@github.com
```

- https://unix.stackexchange.com/questions/5910/wgetpaste-alternatives/5918#5918

## run dhclient on start

I have used http://git.savannah.gnu.org/cgit/guix.git/tree/gnu/system/examples/vm-image.tmpl?h=v0.16.0 as a base.

In the vm-image.tmpl there is file system label specified as `my-root`. I wanted to keep it.

So first check the label and set it:

```bash
$ sudo lsblk -o name,mountpoint,label,size,uuid
$ e2label /dev/sda1 my-root
```

- https://unix.stackexchange.com/questions/14165/list-partition-labels-from-the-command-line/108951#108951
- https://www.tecmint.com/change-modify-linux-disk-partition-label-names/


Added dhcp service as shown here:

- https://www.gnu.org/software/guix/manual/en/html_node/Using-the-Configuration-System.html#Using-the-Configuration-System
- http://git.savannah.gnu.org/cgit/guix.git/tree/gnu/system/examples/bare-bones.tmpl?h=v0.16.0

and run:

```bash
$ guix system reconfigure vm-image.tmpl
```

After rebooting, new grub entry appeared and now dhclient is run on start.

## ssh server

Inside guix

```bash
$ guix package -i openssh
$ groupadd -g 50 sshd
$ useradd  -c 'sshd PrivSep' -d /var/lib/sshd -m -g sshd -s /bin/false -u 50 sshd 
```

## services

systemd is not an option https://lists.gnu.org/archive/html/guix-devel/2018-04/msg00050.html
