# Lium.io GPU node (Bittensor subnet 51) as a boot-time specialisation.
#
# Lium nodes require Ubuntu + Sysbox, neither of which runs on NixOS. So the
# "lium" boot entry turns this host into a headless hypervisor: the RTX 5090 is
# bound to vfio-pci in the initrd (the NVIDIA driver never loads) and handed to
# an Ubuntu 24.04 VM, which is provisioned automatically via cloud-init:
#   - root disk from the Ubuntu cloud image, data disk as XFS (pquota) for
#     /var/lib/docker (both preallocated, see diskGiB options)
#   - NVIDIA open DKMS driver, Docker CE 28.x
# The Lium node itself is installed once by hand inside the VM:
#   curl -fsSL https://lium.io/mine.sh | bash -s -- --register <token>
#
# Networking: the VM sits directly in the LAN via macvtap (own MAC/DHCP lease).
# Router port forwards (8080, 2200, 20000+) must point to the VM's IP. The host
# cannot reach the VM over macvtap; use `virsh console lium-node` on the host,
# or SSH from another LAN machine. Deliberately no Tailscale in the VM: renters
# may get root there and would end up inside the tailnet.
#
# Disk images are created only once, on the first boot into "lium"; changing
# sizes later requires deleting them in /var/lib/libvirt/images/lium-node.
# cloud-init also only runs on first boot (fixed instance-id).
{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkMerge mkOption types;
  cfg = config.services.lium-node;
  vm = cfg.vm;

  virsh = "${config.virtualisation.libvirtd.package}/bin/virsh --connect qemu:///system";
  qemuImg = "${pkgs.qemu-utils}/bin/qemu-img";
  imageDir = "/var/lib/libvirt/images/${vm.name}";

  ubuntuImage = pkgs.fetchurl {
    url = "https://cloud-images.ubuntu.com/releases/noble/release-20261017/ubuntu-24.04-server-cloudimg-amd64.img";
    sha256 = "04e8f2461a16a44e78a370284471f29616cdd9baf1893df25807b71f985b6c94";
  };

  # cloud-config is YAML; JSON is valid YAML and avoids quoting issues.
  userData = pkgs.writeText "user-data" ("#cloud-config\n"
    + builtins.toJSON {
      hostname = vm.name;
      timezone = config.time.timeZone;
      users = [
        {
          name = cfg.user;
          shell = "/bin/bash";
          sudo = "ALL=(ALL) NOPASSWD:ALL";
          ssh_authorized_keys = cfg.sshKeys;
        }
      ];
      ssh_pwauth = false;

      # Data disk: XFS with ftype=1, mounted with pquota so Docker can enforce
      # per-container disk limits (--storage-opt size=...), as Lium requires.
      fs_setup = [
        {
          label = "docker";
          filesystem = "xfs";
          device = "/dev/vdb";
          partition = "none";
          extra_opts = ["-n" "ftype=1"];
        }
      ];
      mounts = [
        ["LABEL=docker" "/var/lib/docker" "xfs" "defaults,inode64,pquota,nofail" "0" "2"]
      ];

      # Lium supports Docker 27/28 out of the box; 29 needs extra daemon config.
      write_files = [
        {
          path = "/etc/apt/preferences.d/docker-ce";
          content = ''
            Package: docker-ce docker-ce-cli
            Pin: version 5:${cfg.dockerVersion}.*
            Pin-Priority: 1001
          '';
        }
        # Self-healing: once dockerd gives up (restart limit hit), reboot the
        # VM. A guest reboot clears broken vCPU state (seen 2026-10-26: all
        # processes on one vCPU segfaulting) and the GPU survives it. The
        # uptime guard prevents a reboot loop if Docker is broken for real.
        {
          path = "/etc/systemd/system/docker.service.d/reboot-on-failure.conf";
          content = ''
            [Unit]
            OnFailure=lium-recover.service
          '';
        }
        {
          path = "/etc/systemd/system/lium-recover.service";
          content = ''
            [Unit]
            Description=Reboot the Lium node VM after docker.service failed

            [Service]
            Type=oneshot
            ExecStart=/usr/local/sbin/lium-recover
          '';
        }
        {
          path = "/usr/local/sbin/lium-recover";
          permissions = "0755";
          content = ''
            #!/bin/sh
            up=$(cut -d. -f1 /proc/uptime)
            if [ "$up" -lt 900 ]; then
              echo "docker failed ''${up}s after boot, not rebooting (loop guard)"
              exit 0
            fi
            echo "docker failed, rebooting VM"
            systemctl reboot
          '';
        }
        # Grow the XFS docker filesystem into the data disk on every boot, so
        # raising dataDiskGiB on the host takes effect after a VM restart.
        # Online and a no-op when there is nothing to grow.
        {
          path = "/etc/systemd/system/lium-growfs.service";
          content = ''
            [Unit]
            Description=Grow the XFS docker filesystem to the data disk size
            RequiresMountsFor=/var/lib/docker
            Before=docker.service

            [Service]
            Type=oneshot
            ExecStart=/usr/sbin/xfs_growfs /var/lib/docker

            [Install]
            WantedBy=multi-user.target
          '';
        }
      ];
      apt.sources.docker = {
        source = "deb [arch=amd64 signed-by=$KEY_FILE] https://download.docker.com/linux/ubuntu $RELEASE stable";
        keyid = "9DC858229FC7DD38854AE2D88D81803C0EBFCD88";
      };
      package_update = true;
      # No full upgrade on first boot: a new kernel would need a VM reboot
      # before the DKMS driver loads. unattended-upgrades handles it later.
      package_upgrade = false;
      packages = [
        "docker-ce"
        "docker-ce-cli"
        "containerd.io"
        "docker-buildx-plugin"
        "docker-compose-plugin"
        "xfsprogs"
        "jq"
      ];

      runcmd = [
        # DKMS-managed NVIDIA driver (Lium requirement), built for the running
        # kernel and for the kernel metapackage so future kernels get it too.
        ''
          set -e
          apt-get install -y "linux-headers-$(uname -r)"
          for m in generic virtual kvm; do
            if dpkg -s "linux-image-$m" >/dev/null 2>&1; then apt-get install -y "linux-headers-$m"; fi
          done
          apt-get install -y nvidia-headless-${cfg.nvidiaDriver}-open nvidia-utils-${cfg.nvidiaDriver}
          modprobe nvidia
        ''
        "usermod -aG docker ${cfg.user}"
        "systemctl enable --now docker"
        "systemctl daemon-reload && systemctl enable lium-growfs.service"
      ];
      final_message = "lium-node provisioned after $UPTIME s";
    });

  metaData = pkgs.writeText "meta-data" ''
    instance-id: ${vm.name}-1
    local-hostname: ${vm.name}
  '';

  seedIso = pkgs.runCommand "${vm.name}-seed.iso" {nativeBuildInputs = [pkgs.cdrkit];} ''
    cp ${userData} user-data
    cp ${metaData} meta-data
    genisoimage -output $out -volid cidata -joliet -rock user-data meta-data
  '';

  # "0000:01:00.1" -> libvirt <address .../>
  pciAddress = addr: let
    m = builtins.match "([0-9a-fA-F]{4}):([0-9a-fA-F]{2}):([0-9a-fA-F]{2})\\.([0-7])" addr;
  in "<address domain='0x${builtins.elemAt m 0}' bus='0x${builtins.elemAt m 1}' slot='0x${builtins.elemAt m 2}' function='0x${builtins.elemAt m 3}'/>";

  hostdevs =
    lib.concatMapStrings (addr: ''
      <hostdev mode='subsystem' type='pci' managed='yes'>
        <source>${pciAddress addr}</source>
      </hostdev>
    '')
    cfg.gpu.pciAddresses;

  domainXml = pkgs.writeText "${vm.name}.xml" ''
    <domain type='kvm' xmlns:qemu='http://libvirt.org/schemas/domain/qemu/1.0'>
      <name>${vm.name}</name>
      <memory unit='GiB'>${toString vm.memoryGiB}</memory>
      <vcpu placement='static'>${toString vm.vcpus}</vcpu>
      <os firmware='efi'>
        <type arch='x86_64' machine='q35'>hvm</type>
        <!-- no Secure Boot: the DKMS-built NVIDIA modules are unsigned -->
        <firmware><feature enabled='no' name='secure-boot'/></firmware>
        <boot dev='hd'/>
      </os>
      <features><acpi/><apic/></features>
      <cpu mode='host-passthrough' check='none' migratable='off'>
        <topology sockets='1' dies='1' cores='${toString (vm.vcpus / 2)}' threads='2'/>
        <maxphysaddr mode='passthrough'/>
      </cpu>
      <clock offset='utc'/>
      <on_poweroff>destroy</on_poweroff>
      <on_reboot>restart</on_reboot>
      <on_crash>destroy</on_crash>
      <devices>
        <disk type='file' device='disk'>
          <driver name='qemu' type='raw' cache='none' io='native'/>
          <source file='${imageDir}/root.img'/>
          <target dev='vda' bus='virtio'/>
        </disk>
        <disk type='file' device='disk'>
          <driver name='qemu' type='raw' cache='none' io='native'/>
          <source file='${imageDir}/data.img'/>
          <target dev='vdb' bus='virtio'/>
        </disk>
        <disk type='file' device='cdrom'>
          <driver name='qemu' type='raw'/>
          <source file='${imageDir}/seed.iso'/>
          <target dev='sda' bus='sata'/>
          <readonly/>
        </disk>
        <interface type='direct'>
          <mac address='${vm.macAddress}'/>
          <source dev='${vm.hostInterface}' mode='bridge'/>
          <model type='virtio'/>
        </interface>
        ${hostdevs}
        <serial type='pty'><target port='0'/></serial>
        <console type='pty'><target type='serial' port='0'/></console>
        <rng model='virtio'><backend model='random'>/dev/urandom</backend></rng>
        <memballoon model='none'/>
      </devices>
      <!-- 64 GiB 64-bit MMIO window so the 32 GiB resizable BAR fits -->
      <qemu:commandline>
        <qemu:arg value='-fw_cfg'/>
        <qemu:arg value='opt/ovmf/X-PciMmio64Mb,string=65536'/>
      </qemu:commandline>
    </domain>
  '';
in {
  options.services.lium-node = {
    enable = mkEnableOption "the \"lium\" boot specialisation (GPU passthrough to an Ubuntu Lium node VM)";

    bootByDefault = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Make the newest generation's "lium" entry the systemd-boot default, so
        the machine comes back as a Lium node after every reboot. The normal
        desktop stays selectable in the boot menu.
      '';
    };

    active = mkOption {
      type = types.bool;
      default = false;
      internal = true;
      description = "True only inside the lium specialisation. Modules that need the GPU on the host gate on this.";
    };

    user = mkOption {
      type = types.str;
      default = "chrissi";
      description = "Login user created inside the VM.";
    };

    sshKeys = mkOption {
      type = types.listOf types.str;
      default = config.users.users.${cfg.user}.openssh.authorizedKeys.keys;
      defaultText = lib.literalExpression "config.users.users.\${user}.openssh.authorizedKeys.keys";
      description = "SSH public keys authorized for the VM user.";
    };

    nvidiaDriver = mkOption {
      type = types.str;
      default = "580";
      description = "Ubuntu NVIDIA driver branch (installs nvidia-headless-<v>-open, DKMS).";
    };

    dockerVersion = mkOption {
      type = types.str;
      default = "28";
      description = "Docker CE major version pinned inside the VM.";
    };

    gpu = {
      pciIds = mkOption {
        type = types.listOf types.str;
        example = ["10de:2b85" "10de:22e8"];
        description = "vendor:device IDs bound to vfio-pci (GPU + its audio function).";
      };
      pciAddresses = mkOption {
        type = types.listOf types.str;
        example = ["0000:01:00.0" "0000:01:00.1"];
        description = "PCI addresses passed through to the VM.";
      };
    };

    vm = {
      name = mkOption {
        type = types.str;
        default = "lium-node";
      };
      vcpus = mkOption {
        type = types.int;
        description = "vCPUs (even number; exposed as cores x 2 threads).";
      };
      memoryGiB = mkOption {type = types.int;};
      rootDiskGiB = mkOption {type = types.int;};
      dataDiskGiB = mkOption {
        type = types.int;
        description = "XFS data disk for /var/lib/docker (renter containers).";
      };
      macAddress = mkOption {
        type = types.str;
        default = "52:54:00:4c:49:55";
        description = "Fixed MAC so the router can hand out a stable DHCP lease.";
      };
      hostInterface = mkOption {
        type = types.str;
        description = "Host NIC the VM's macvtap interface attaches to.";
      };
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      specialisation.lium.configuration = {
        system.nixos.tags = ["lium"];
        services.lium-node.active = true;
      };
    })

    # The systemd-boot builder always writes the base generation as default;
    # this runs right after it and points loader.conf at the same
    # generation's lium entry instead. An EFI "LoaderEntryDefault" variable
    # (set via the menu's `d` key or `bootctl set-default`) would still take
    # precedence over loader.conf and keep booting a stale entry forever, so
    # it is cleared on every rebuild: loader.conf is the single source of truth.
    (mkIf (cfg.enable && cfg.bootByDefault) {
      boot.loader.systemd-boot.extraInstallCommands = let
        esp = config.boot.loader.efi.efiSysMountPoint;
      in ''
        ${pkgs.systemd}/bin/bootctl --esp-path=${esp} set-default "" || true
        conf=${esp}/loader/loader.conf
        gen=$(${pkgs.gnused}/bin/sed -n 's/^default \(nixos-generation-[0-9]*\)\.conf$/\1/p' "$conf")
        if [ -n "$gen" ] && [ -f "${esp}/loader/entries/$gen-specialisation-lium.conf" ]; then
          ${pkgs.gnused}/bin/sed -i "s/^default .*/default $gen-specialisation-lium.conf/" "$conf"
          echo "systemd-boot default: $gen-specialisation-lium.conf"
        fi
      '';
    })

    (mkIf cfg.active {
      assertions = [
        {
          assertion = lib.mod vm.vcpus 2 == 0;
          message = "services.lium-node.vm.vcpus must be even.";
        }
      ];

      # Claim the GPU with vfio-pci in the initrd, before any driver can.
      # AVIC off: rules out a historically fragile KVM path after a guest vCPU
      # got into a broken state (2026-10-26). Negligible cost for this VM.
      #
      # clearcpuid=519 hides CET shadow stacks (CPUID.7.0:ECX[7], Linux feature
      # word 16*32+7) from the host, so KVM 6.18 stops exposing them to the
      # guest. QEMU 10.2 does not know CET, and with it passed through a guest
      # vCPU ended up with a stale shadow stack pointer: every process on that
      # vCPU died with shadow-stack page faults (error code bit 0x40) at one
      # fixed address, taking dockerd and the executor down within minutes.
      boot.kernelParams = ["amd_iommu=on" "iommu=pt" "kvm_amd.avic=0" "clearcpuid=519"];
      boot.initrd.kernelModules = ["vfio_pci" "vfio" "vfio_iommu_type1"];
      boot.extraModprobeConfig = "options vfio-pci ids=${lib.concatStringsSep "," cfg.gpu.pciIds}";
      boot.blacklistedKernelModules = ["nvidia" "nvidia_drm" "nvidia_modeset" "nvidia_uvm" "nouveau"];

      virtualisation.libvirtd = {
        enable = true;
        # QEMU as unprivileged qemu-libvirtd instead of root, so a VM escape by
        # a renter does not land as root on the host. libvirt chowns disks,
        # NVRAM and /dev/vfio/* to that user when the VM starts.
        qemu.runAsRoot = false;
        # lium-vm.service starts the VM; libvirt-guests shuts it down cleanly
        # (suspend/managedsave does not work with a passed-through GPU).
        onBoot = "ignore";
        onShutdown = "shutdown";
        shutdownTimeout = 180;
      };

      systemd.services.lium-vm = {
        description = "Lium node VM (${vm.name})";
        requires = ["libvirtd.service"];
        after = ["libvirtd.service" "network-online.target"];
        wants = ["network-online.target"];
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          TimeoutStartSec = "30min"; # preallocating the disks takes a while
        };
        script = ''
          set -euo pipefail
          mkdir -p ${imageDir}

          if [ ! -e ${imageDir}/root.img ]; then
            echo "Creating root disk (${toString vm.rootDiskGiB} GiB, preallocated)"
            ${qemuImg} convert -f qcow2 -O raw ${ubuntuImage} ${imageDir}/root.img.tmp
            ${qemuImg} resize -f raw ${imageDir}/root.img.tmp ${toString vm.rootDiskGiB}G
            ${pkgs.util-linux}/bin/fallocate -l ${toString vm.rootDiskGiB}GiB ${imageDir}/root.img.tmp
            mv ${imageDir}/root.img.tmp ${imageDir}/root.img
          fi

          if [ ! -e ${imageDir}/data.img ]; then
            echo "Creating data disk (${toString vm.dataDiskGiB} GiB, preallocated)"
            ${pkgs.util-linux}/bin/fallocate -l ${toString vm.dataDiskGiB}GiB ${imageDir}/data.img.tmp
            mv ${imageDir}/data.img.tmp ${imageDir}/data.img
          fi

          # Grow (never shrink) existing images when the configured size was
          # raised. The guest grows its filesystems on boot: cloud-init
          # growpart for /, lium-growfs.service (xfs_growfs) for the data disk.
          grow() {
            local img=$1 want=$(( $2 * 1024 * 1024 * 1024 )) cur
            cur=$(stat -c %s "$img")
            if [ "$cur" -lt "$want" ]; then
              echo "Growing $img from $(( cur / 1024 / 1024 / 1024 )) to $2 GiB (preallocated)"
              ${pkgs.util-linux}/bin/fallocate -l "$want" "$img"
            elif [ "$cur" -gt "$want" ]; then
              echo "WARNING: $img is larger than configured $2 GiB; not shrinking" >&2
            fi
          }
          grow ${imageDir}/root.img ${toString vm.rootDiskGiB}
          grow ${imageDir}/data.img ${toString vm.dataDiskGiB}

          install -m 0644 ${seedIso} ${imageDir}/seed.iso

          if [ "$(${virsh} domstate ${vm.name} 2>/dev/null)" = "running" ]; then
            echo "${vm.name} already running"
            exit 0
          fi
          # The XML carries no <uuid>, so libvirt would refuse to redefine an
          # existing domain under a fresh one. Re-create it from the current
          # XML on every start; disks and NVRAM (UEFI vars) are kept.
          if ${virsh} dominfo ${vm.name} >/dev/null 2>&1; then
            ${virsh} undefine --keep-nvram ${vm.name}
          fi
          ${virsh} define ${domainXml}
          ${virsh} start ${vm.name}
        '';
      };
    })
  ];
}
