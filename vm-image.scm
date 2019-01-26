;;; This is an operating system configuration template for a "bare-bones" setup,
;;; suitable for booting in a virtualized environment, including virtual private
;;; servers (VPS).

(use-modules (gnu))
(use-service-modules networking)
(use-package-modules bootloaders disk nvi)

(define vm-image-motd (plain-file "motd" "
This is the GNU system.  Welcome!

This instance of GuixSD is a bare-bones template for virtualized environments.

You will probably want to do these things first if you booted in a virtual
private server (VPS):

* Set a password for 'root'.
* Set up networking.
* Expand the root partition to fill the space available by 0) deleting and
recreating the partition with fdisk, 1) reloading the partition table with
partprobe, and then 2) resizing the filesystem with resize2fs.\n"))

(operating-system
  (host-name "gnu")
  (timezone "Etc/UTC")
  (locale "en_US.utf8")

  (firmware '())

  ;; Assuming /dev/sdX is the target hard disk, and "my-root" is
  ;; the label of the target root file system.
  (bootloader (bootloader-configuration
               (bootloader grub-bootloader)
               (target "/dev/sda")
               (terminal-outputs '(console))))
  (file-systems (cons (file-system
                        (device (file-system-label "my-root"))
                        (mount-point "/")
                        (type "ext4"))
                      %base-file-systems))

;; sshd group and user
;; http://www.linuxfromscratch.org/blfs/view/stable/postlfs/openssh.html
;; https://www.gnu.org/software/guix/manual/en/html_node/User-Accounts.html
  (groups (cons (user-group
                  (name "sshd")
		  ;; could not set this, was set to 30001
		  (id 50))
                 %base-groups))
  ;; This is where user accounts are specified.  The "root"
  ;; account is implicit, and is initially created with the
  ;; empty password.
  (users (cons (user-account
                (name "sshd")
                (comment "sshd PrivSep")
                (group "sshd")
                (uid 50)
                (shell "/bin/false")
                (home-directory "/var/lib/sshd"))
               %base-user-accounts))

  ;; Globally-installed packages.
  (packages (append (list nvi fdisk
                          ;; mostly so xrefs to its manual work
                          grub
                          ;; partprobe
                          parted)
                    %base-packages))

  (services (cons* (service dhcp-client-service-type) (modify-services %base-services
              (login-service-type config =>
                                  (login-configuration
                                    (inherit config)
                                    (motd vm-image-motd)))))))
