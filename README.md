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
# there is also reboot command
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
$ qemu-system-x86_64 -net user -net nic,model=virtio -cpu host -enable-kvm -m 1024 guixsd-vm-image-0.16.0.x86_64-linux
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

The "Nested VMX" feature adds this missing capability - of running guest
hypervisors (which use VMX) with their own nested guests.

https://www.kernel.org/doc/Documentation/virtual/kvm/nested-vmx.txt

Solved by running qemu with `-cpu host -enable-kvm` parameters.

Running with `-cpu qemu64,+vmx -enable-kvm`

https://stackoverflow.com/questions/39154850/how-to-emulate-vmx-feature-with-qemu/39277264#39277264

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

For networking we use user mode with port forwarding. Without port forwarding it is not possible in user mode to connect from host to guest:

`qemu-system-x86_64 -net user,hostfwd=tcp::10022-:22 -net nic,model=virtio -cpu host -enable-kvm -m 1024 guixsd-vm-image-0.16.0.x86_64-linux`

We can also use `-nic` option to avoid creating hub https://www.qemu.org/2018/05/31/nic-parameter/

`qemu-system-x86_64 -net user,hostfwd=tcp::10022-:22 -net nic,model=virtio -cpu host -enable-kvm -m 1024 guixsd-vm-image-0.16.0.x86_64-linux`

Inside guix

```bash
$ guix package -i openssh
```

user and group needed for sshd are specified in `vm-image.scm` inside this repository. This way you will have this user and group after restart:

`guix system reconfigure vm-image.scm`.

You can also temporarily create it:

```bash
$ groupadd -g 50 sshd
$ useradd  -c 'sshd PrivSep' -d /var/lib/sshd -m -g sshd -s /bin/false -u 50 sshd 
```

Let's run the sshd:

```bash
# set passwd for root if it is not set
$ passwd
$ echo PermitRootLogin yes >> /etc/ssh/sshd_config
$ ssh-keygen -t ecdsa -N "" -f /etc/ssh/ssh_host_ecdsa_key
$ ~/.guix-profile/sbin/sshd -f /etc/ssh/sshd_config
```

Now on the host:

`ssh -p10022 root@localhost`

- based on https://qemu.weilnetz.de/doc/qemu-doc.html#Network-options nad telnet example for hostfwd option
- https://en.wikibooks.org/wiki/QEMU/Networking
- https://wiki.debian.org/QEMU#Networking

## More networking

I can run `serve` static html file on host and download it in guest with `wget 192.168.0.17:5000`.


```bash
$ nmap -Pn -n 10.105.2.65
Starting Nmap 7.70 ( https://nmap.org ) at 2019-01-28 10:10 CET
Nmap scan report for 10.105.2.65
Host is up.
All 1000 scanned ports on 10.105.2.65 are filtered

Nmap done: 1 IP address (1 host up) scanned in 201.35 seconds
```

[How to allow ping between ubuntu 14.04 qemu host and windows guests](https://ubuntuforums.org/showthread.php?t=2232093)



## services

systemd is not an option https://lists.gnu.org/archive/html/guix-devel/2018-04/msg00050.html

## julia

Now there is 1.1.0 version and in guix it is 0.6.0 https://www.gnu.org/software/guix/packages/J/

## vs snap and flatpak etc.

I agree with a lot of this. GNU/Linux distros are going down a very dangerous path with Snappy, Docker, Flatpak, Atomic, etc. I think a lot of this is responding to the fact that traditional systems package managers are quite bad by today's standards. They are imperative (no atomic transactions), use global state (/usr), and require root privileges. Snappy and co. take the "fuck it, I'm out" approach of bundling the world with your application, which is terrible for user control and security. Instead, I urge folks to check out the functional package managers GNU Guix[0] and Nix[1], and their accompanying distributions GuixSD and NixOS. Both Guix and Nix solve the problems of traditional systems package managers, while adding additional useful features (like reproducible builds, universal virtualenv, and full-system config management) and avoiding the massive drawbacks of Snappy and friends.

https://news.ycombinator.com/item?id=11911871


Both Nix and Guix provide amazing tools for sandboxing. And for reproducibility, rollbacks...

I think Snap/Flatpack are a much inferior solution vs Nix/Guix. Imagine a heartbleed-like scenario. With Nix/Guix, you know exactly what is running in your computer. With containers, it's a lot trickier. Plus you can't really reproduce builds or patch them.

Snap/Flatpack means moving into the macOS model of Apps. I don't want Apps. I want package management, which is one of the key advantages of Linux.

https://www.reddit.com/r/linux/comments/7drgl6/with_nix_and_guix_around_why_do_we_need_snaps_and/dq06sqd/


I initially liked the idea of Nix, but I didn't like NixOS. The implementation has accumulated some cruft. It's undergoing major refactorings now, so it will probably get much better.

My piece of advice is that you try GuixSD. It's very elegant. Some reasons I love it (most apply to Nix too):

    My whole system configuration is a reproducible DSL (Scheme) file.

    I can rollback to any system configuration. Thus, I can't break my system.

    Containers are baked in (answers your question).

    All packages are reproducible. I can challenge the binary I'm getting from a repo, rebuild it from source and see whether both match.

    You can install multiple versions of any package. You get the best of both worlds: rolling and stable releases.

    Since package builds are reproducible recipes, it's trivial to inherit from a given recipe (say Linux kernel), alter a few things (say change the repo to linux-zen and add a few flags). You get the best of both worlds: binary and source based distros.

    Guix can use Nix packages and vice versa.

Snap and Flatpack make sense for big deployments or weird proprietary binaries.

https://www.reddit.com/r/linux/comments/7drgl6/with_nix_and_guix_around_why_do_we_need_snaps_and/dq0bhmo/


I have solved the problem of reproducibility and rollbacks for myself, thank you, without the complexity of NixOS (never used guix, so maybe I am missing out there). I use squashfs images backed by dm_verity together with a signed kernel. So I know that if the machine boots, then it is in exactly the state I installed it -- and nodoby can have changed anything in the meantime, not even root. I have not found any way to get a similarly strong guarantee in NixOS.

https://www.reddit.com/r/linux/comments/7drgl6/with_nix_and_guix_around_why_do_we_need_snaps_and/dq0agli/

## about

We offer deblobbed Linux (linux-libre) by default.

However, it is very simple to customise packages, including the kernel package, e.g. to apply patches, use different sources, or to exercise your right to disagree with the Linux libre upstream on what blobs should be deleted from the kernel.

That said, I consider freedom by default a feature and it works very well on most of the hardware I use (an exception is an on-board Radeon graphics chip in a desktop machine I don't use much).

Creating package variants is almost trivial; it's certainly no harder than, say, customising Emacs. Guix blurs the lines between user and maintainer, so using custom package definitions is a supported use-case. At work even our scientist users create custom packages in case they are not available in Guix upstream yet. 

https://news.ycombinator.com/item?id=11915224
