<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [ansible-rpi-k8s-cluster](#ansible-rpi-k8s-cluster)
  - [Background](#background)
    - [Why?](#why)
    - [How It Works](#how-it-works)
  - [Requirements](#requirements)
    - [Software](#software)
      - [Ansible](#ansible)
      - [Kubernetes CLI Tools](#kubernetes-cli-tools)
    - [Hardware](#hardware)
    - [Installing OS](#installing-os)
      - [Downloading OS](#downloading-os)
      - [Installing OS](#installing-os-1)
        - [First SD Card](#first-sd-card)
          - [Install OS Image](#install-os-image)
        - [Remaining SD cards](#remaining-sd-cards)
  - [Deploying](#deploying)
    - [Ansible Variables](#ansible-variables)
    - [Ansible Playbook](#ansible-playbook)
    - [Managing WI-FI On First Node](#managing-wi-fi-on-first-node)
  - [Load Balancing And Exposing Services](#load-balancing-and-exposing-services)
    - [Deploying Traefik](#deploying-traefik)
    - [Accessing Traefik WebUI](#accessing-traefik-webui)
  - [Kubernetes Dashboard](#kubernetes-dashboard)
    - [kubectl proxy](#kubectl-proxy)
    - [SSH Tunnel](#ssh-tunnel)
    - [Admin Privileges](#admin-privileges)
  - [Persistent Storage](#persistent-storage)
    - [GlusterFS](#glusterfs)
    - [Deploying GlusterFS In Kubernetes](#deploying-glusterfs-in-kubernetes)
    - [Using GlusterFS In Kubernetes Pod](#using-glusterfs-in-kubernetes-pod)
  - [License](#license)
  - [Author Information](#author-information)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# ansible-rpi-k8s-cluster

This repo will be used for deploying a Kubernetes cluster on Raspberry Pi using
Ansible.

## Background

### Why?

I have been looking at putting together a Kubernetes cluster using Raspberry
Pi's for a while now. And I finally pulled all of it together and started pulling
together numerous `Ansible` roles which I had already developed over time. I
wanted this whole project to be provisioned with `Ansible` so I had a repeatable
process to build everything out. As well as a way to share with others. I am
still putting all of the pieces together so this will no doubt be a continual
updated repo for some time.

### How It Works

The following will outline the design of how this current iteration works.
Basically we have a 5 (or more) node Raspberry Pi cluster. With the first node
connecting to wireless to act as our gateway into the cluster. The first node is
by far the most critical. We use the first nodes wireless connection to also do
all of our provisioning of our cluster. We execute `Ansible` against all of the
remaining nodes by using the first node as a bastion host via it's wireless IP.
Once you obtain the IP of the first node's wireless connection you need to
update `jumphost_ip:` in [inventory/group_vars/all/all.yml](inventory/group_vars/all/all.yml)
as well as change the `ansible_host` for `rpi-k8s-1 ansible_host=172.16.24.186`
in [inventory/hosts.inv](inventory/hosts.inv). If you would like to change the
subnet which the cluster will use, change `dhcp_scope_subnet:` in [inventory/group_vars/all/all.yml]
to your desired subnet as well as the `ansible_host` addresses for the following
nodes in [inventory/hosts.inv](inventory/hosts.inv):

```bash
[rpi_k8s_slaves]
rpi-k8s-2 ansible_host=192.168.100.128
rpi-k8s-3 ansible_host=192.168.100.129
rpi-k8s-4 ansible_host=192.168.100.130
rpi-k8s-5 ansible_host=192.168.100.131
```

> NOTE: We may change to an automated inventory being generated if it makes things
> a little more easy.

The first node provides the following services for our cluster:

-   DHCP for all of the other nodes (only listening on `eth0`)
-   Gateway services for other nodes to connect to the internet and such.
    -   An IPTABLES Masquerade rule NATs traffic from `eth0` through `wlan0`

> NOTE: You can also define a static route on your LAN network firewall (if supported)
> for the subnet (`192.168.100.0/24` in my case) to the wireless IP address that
> your first node obtains. This will allow you to communicate with all of the
> cluster nodes once they get an IP via DHCP from the first node.

For Kubernetes networking we are using [Weave Net](https://www.weave.works/docs/net/latest/kubernetes/kube-addon/).

## Requirements

### Software

The following is a list of the required packages to be installed on your `Ansible`
control machine (the machine you will be executing Ansible from).

#### Ansible

You can install `Ansible` in many different ways so head over to the official
`Ansible` [intro installation](http://docs.ansible.com/ansible/latest/intro_installation.html).

#### Kubernetes CLI Tools

You will also need to install the `kubectl` package. As with `Ansible`
there are many different ways to install `kubectl` so head over to the official
`Kubernetes` [Install and Set Up kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/).

> NOTE: The Ansible playbook [playbooks/deployments.yml](playbooks/deployments.yml)
> fetches the `admin.conf` from the K8s master and copies this to your local
> $HOME/.kube/config. This allows us to run `kubectl` commands remotely to the
> cluster. There is a catch here though. The certificate is signed with the
> internal IP address of the K8s master. So in order for this to work correctly
> you will need to setup a static route on your firewall (if supported) to the
> subnet `192.168.100.0/24`(in our case) via the wireless IP on your first
> node (also the K8s master).

### Hardware

The following list is the hardware which I am using currently while developing
this.

-   5 x [Raspberry Pi 3](http://amzn.to/2EbDKfq)
-   2 x [6pack - Cat 6 - Flat Ethernet Cables](http://amzn.to/2nKvywD)
-   1 x [Anker PowerPort 6 - 60W 6-Port Charging Hub](http://amzn.to/2ERkV2q)
-   5 x [Samsung 32GB 95MB/s MicroSD Evo Memory Card](http://amzn.to/2skSlno)
-   1 x [GeauxRobot Raspberry Pi 3 5-Layer Dog Bone Stack Case](http://amzn.to/2Edbqcw)
-   1 x 8-Port Ethernet Switch

### Installing OS

Currently I am using [Raspbian Lite](http://raspbian.org/) for the OS. I did
not orginally go with Hyperiot intentionally but may give it a go at some point.

#### Downloading OS

Head over [here](https://www.raspberrypi.org/downloads/raspbian/) and download
the `RASPBIAN STRETCH LITE` image.

#### Installing OS

I am using a Mac so my process will based on that so you may need to adjust
based on your OS.

After you have finished [downloading](#downloading-os) the OS you will want to
extract the zip file `2017-11-29-raspbian-stretch-lite.zip` in my case. After
extrating the file you are ready to load the OS onto each and every SD card. In
my case I am paying special attention to the first one. The first one we will be
adding the `wpa_supplicant.conf` file which will connect us to wireless. We will
use wireless as our gateway into the cluster. We want to keep this as isolated
as possible.

##### First SD Card

With our zip file extracted we are now ready to load the image onto our SD card.
Remember what I mentioned above, the first one is the one which we will use to
connect to wireless.

###### Install OS Image

> NOTE: Remember I am using a Mac so YMMV! You may also want to look into
> [Etcher](https://etcher.io/) for a GUI based approach.

Open up your terminal and execute the following to determine the device name of
the SD card:

```bash
diskutil list
...
/dev/disk0 (internal, physical):
   #:                       TYPE NAME                    SIZE       IDENTIFIER
   0:      GUID_partition_scheme                        *500.3 GB   disk0
   1:                        EFI EFI                     209.7 MB   disk0s1
   2:          Apple_CoreStorage macOS                   499.4 GB   disk0s2
   3:                 Apple_Boot Recovery HD             650.0 MB   disk0s3

/dev/disk1 (internal, virtual):
   #:                       TYPE NAME                    SIZE       IDENTIFIER
   0:                  Apple_HFS macOS                  +499.0 GB   disk1
                                 Logical Volume on disk0s2
                                 7260501D-EA09-4048-91FA-3A911D627C9B
                                 Unencrypted

/dev/disk2 (external, physical):
   #:                       TYPE NAME                    SIZE       IDENTIFIER
   0:     FDisk_partition_scheme                        *32.0 GB     disk2
   1:                 DOS_FAT_16 NEW VOLUME              32.0 GB     disk2s1
```

From the above in my case I will be using `/dev/disk2` which is my SD card.

Now we need to unmount the disk so we can write to it:

```bash
diskutil unmountdisk /dev/disk2
```

Now that our SD card is unmounted we are ready to write the OS image to it. And
we do that by running the following in our terminal:

```bash
sudo dd bs=1m if=/Users/larry/Downloads/2017-11-29-raspbian-stretch-lite.img of=/dev/disk2 conv=sync
```

After that completes we now need to remount the SD card so that we can write
some files to it.

```bash
diskutil mountdisk /dev/disk2
```

Now we need to change into the directory in which our SD card is mounted:

```bash
cd /Volumes/boot
```

First we need to create a blank file `ssh` onto the SD card to enable SSH when
the Pi boots up.

```bash
touch ssh
```

Next we need to create the `wpa_supplicant.conf` file which will contain the
configuration to connect to wireless. The contents of this file are listed below:

`wpa_supplicant.conf`:

```bash
country=US
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
    ssid="your_real_wifi_ssid"
    scan_ssid=1
    psk="your_real_password"
    key_mgmt=WPA-PSK
}
```

Now that you have finished creating these files you can then unmount the SD card:

```bash
cd ~
diskutil unmountdisk /dev/disk2
```

Now set this first one aside or place it into your Raspberry Pi that you want to
be the first node.

##### Remaining SD cards

For the remaining SD cards you will follow the same process as in [First SD Card](#first-sd-card)
except you will not create the `wpa_supplicant.conf` file on these. Unless you
want to use wireless for all of your Pi's. If that is the case then that will be
out of scope for this project (for now!).

## Deploying

### Ansible Variables

Most variables that need to be adjusted based on deployment can be found in
[inventory/group_vars/all/all.yml](inventory/group_vars/all/all.yml).

### Ansible Playbook

To provision the full stack you can run the following:

```bash
ansible-playbook -i inventory playbooks/deploy.yml
```

### Managing WI-FI On First Node

To manage the WI-FI connection on your first node. You can create a `wifi.yml`
file in `inventory/group_vars/all` with the following defined variables:

> NOTE: `wifi.yml` is added to the `.gitignore` to ensure that the file is excluded
> from Git. Use your best judgment here. It is probably a better idea to encrypt
> this file with `ansible-vault`. The task(s) to manage WI-FI are in [playbooks/bootstrap.yml](playbooks/bootstrap.yml) and will only trigger if the
> variables defined below exist.

```yaml
k8s_wifi_country: US
k8s_wifi_password: mysecretwifipassword
k8s_wifi_ssid: mywifissid
```

> CAUTION: If your WI-FI IP address changes, `Ansible` will fail as it will no
> longer be able to connect to the original IP address. Keep this in mind.

If you would like to simply manange the WI-FI connection you may run the following:

```bash
ansible-playbook -i inventory playbooks/bootstrap.yml --tags rpi-manage-wifi
```

## Load Balancing And Exposing Services

We have included [Traefik](traefik.io) as an available load balancer which can
be deployed to expose cluster services.

### Deploying Traefik

You can deploy `Traefik` by running the following:

```bash
kubectl deploy -f deployments/traefik.yaml
```

### Accessing Traefik WebUI

You can access the Traefik WebUI by heading over to <http://wirelessIP:8080/dashboard/#/>
(replace `wirelessIP` with your actual IP of the wireless address on the first node).

![Traefik](images/2018/02/traefik.png)

## Kubernetes Dashboard

We have included the Kubernetes dashboard as part of the provisioning. By
default the dashboard is only available from within the cluster. So in order to
connect to it you have a few options.

### kubectl proxy

If you have installed `kubectl` on your local machine then you can simply drop
to your terminal and type the following:

```bash
kubectl proxy
...
Starting to serve on 127.0.0.1:8001
```

Now you can open your browser of choice and head [here](http://127.0.0.1:8001/ui)

### SSH Tunnel

> NOTE: This method will also only work if you have a static route into the cluster
> subnet `192.168.100.0/24`.

You can also use an SSH tunnel to your Kubernetes master node (any cluster node
will work, but because the assumption is that the first node will be the only one
accessible over WI-FI). First you need to find the `kubernetes-dashboard`
ClusterIP, and you can do that by executing the following:

```bash
kubectl get svc --namespace kube-system kubernetes-dashboard
...
NAME                   TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
kubernetes-dashboard   ClusterIP   10.106.41.154   <none>        443/TCP   2d
```

And from the above you will see that the ClusterIP is `10.106.41.154`. Now you
can create the SSH tunnel as below:

```bash
ssh -L 8001:10.106.41.154:443 pi@172.16.24.186
```

Now you can open your browser of choice and head [here](https://127.0.0.1:8001/ui)

### Admin Privileges

If you would like to allow admin privileges without requiring either a kubeconfig
or token then you can apply the following `ClusterRoleBinding`:

```bash
kubectl apply -f deployments/dashboard-admin.yaml
```

And now when you connect to the dashboard you can click skip and have full admin
access. This is **obviously** not good practice, so you should delete this
`ClusterRoleBinding` when you are done:

```bash
kubectl delete -f deployments/dashboard-admin.yaml
```

## Persistent Storage

### GlusterFS

We have included [GlusterFS](https://www.gluster.org/) as backend for persistent
storage to be used by containers. We are not using [Heketi](https://github.com/heketi/heketi)
at this time. So all managment of `GlusterFS` is done via `Ansible`. Check out
the `group_vars` in [inventory/group_vars/rpi_k8s/glusterfs.yml](inventory/group_vars/rpi_k8s/glusterfs.yml)
to define the backend bricks and client mounts.

GlusterFS can also be defined to be available in specific namespaces by defining
the following in [inventory/group_vars/all/all.yml](inventory/group_vars/all/all.yml):

```yaml
k8s_glusterfs_namespaces:
  - default
  - kube-system
```

By defining GlusterFS into specific namespaces allows persistent storage to be
available for consumption within those namespaces.

### Deploying GlusterFS In Kubernetes

You must first deploy the Kubernetes `Endpoints` and `Service` defined in
[deployments/glusterfs.yaml](deployments/glusterfs.yaml). This file is dynamically
generated during provisioning if `glusterfs_volume_force_create: true`.

```bash
kubectl apply -f deployments/glusterfs.yaml
```

### Using GlusterFS In Kubernetes Pod

In order to use `GlusterFS` for persistent storage you must define your pod(s) to
do so. Below is an example of a pod definition:

```yaml
---
apiVersion: v1
kind: Pod
metadata:
  name: glusterfs
spec:
  containers:
    - name: glusterfs
      image: armhfbuild/nginx
      volumeMounts:
        - mountPath: /mnt/glusterfs
          name: glusterfsvol
  volumes:
  - name: glusterfsvol
    glusterfs:
      endpoints: glusterfs-cluster
      path: volume-1
      readOnly: false
```

## License

MIT

## Author Information

Larry Smith Jr.

-   [EverythingShouldBeVirtual](http://everythingshouldbevirtual.com)
-   [@mrlesmithjr](https://www.twitter.com/mrlesmithjr)
-   <mailto:mrlesmithjr@gmail.com>
