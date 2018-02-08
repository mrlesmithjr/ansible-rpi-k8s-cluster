# ansible-rpi-k8s-cluster

This repo will be used for deploying a Kubernetes cluster on Raspberry Pi using
Ansible.

## Deploying

### Ansible Variables

Most variables that need to be adjusted based on deployment can be found in
[inventory/group_vars/all/all.yml](inventory/group_vars/all/all.yml).

### Ansible Playbook

To provision the full stack you can run the following:

```bash
ansible-playbook -i inventory playbooks/deploy.yml
```

## Persistent Storage

### GlusterFS

We have included [GlusterFS](https://www.gluster.org/) as backend for persistent
storage to be used by containers. We are not using [Heketi](https://github.com/heketi/heketi)
at this time. So all managment of `GlusterFS` is done via `Ansible`. Check out
the `group_vars` in [inventory/group_vars/rpi_k8s/glusterfs.yml](inventory/group_vars/rpi_k8s/glusterfs.yml)
to define the backend bricks and client mounts.

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
