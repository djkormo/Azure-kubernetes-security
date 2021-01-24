Literature:


```
bash -x kubernetes-install-vm.bash -n k8s-security2021 -g k8s-rg -l northeurope -o create
```

Tests on master node

```bash
export KUBECONFIG='/etc/kubernetes/admin.conf'
kubectl get nodes -o wide
kubectl get pod -n kube-system
kubectl top nodes
kubectl get events -n kube-system --sort-by=.metadata.creationTimestamp
```

<pre>
Enable succeeded: 
[stdout]
NAME                       STATUS   ROLES    AGE     VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION     CONTAINER-RUNTIME
k8s-security2021-master1   Ready    master   3m56s   v1.19.0   10.240.0.4    <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.6
k8s-security2021-worker1   Ready    <none>   3m35s   v1.19.0   10.240.0.5    <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.6
k8s-security2021-worker2   Ready    <none>   3m20s   v1.19.0   10.240.0.6    <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.6
k8s-security2021-worker3   Ready    <none>   3m37s   v1.19.0   10.240.0.7    <none>        Ubuntu 18.04.5 LTS   5.4.0-1036-azure   docker://19.3.6
NAME                                               READY   STATUS    RESTARTS   AGE
calico-kube-controllers-6b8f6f78dc-mwh94           1/1     Running   0          3m39s
calico-node-6q9vj                                  1/1     Running   0          3m38s
calico-node-bsh7k                                  1/1     Running   0          3m39s
calico-node-c9gtb                                  1/1     Running   0          110s
calico-node-svlhj                                  1/1     Running   0          3m36s
coredns-f9fd979d6-mw66p                            1/1     Running   0          3m39s
coredns-f9fd979d6-x8qpk                            1/1     Running   0          3m39s
etcd-k8s-security2021-master1                      1/1     Running   0          3m54s
kube-apiserver-k8s-security2021-master1            1/1     Running   0          3m54s
kube-controller-manager-k8s-security2021-master1   1/1     Running   2          3m54s
kube-proxy-2xc9b                                   1/1     Running   0          110s
kube-proxy-dkh9b                                   1/1     Running   0          3m36s
kube-proxy-t6t7f                                   1/1     Running   0          3m38s
kube-proxy-vhz4l                                   1/1     Running   0          3m39s
kube-scheduler-k8s-security2021-master1            1/1     Running   2          3m54s
</pre>

https://www.linkedin.com/pulse/deploying-self-managed-kubernetes-cluster-azure-using-atul-sharma/?articleId=6655123344125460480

https://samcogan.com/taking-the-cka-exam-as-an-azure-user/

https://aaronmsft.com/posts/azure-vmss-kubernetes-kubeadm/

https://github.com/tmarjomaa/kubernetesplayground

https://github.com/ankursoni/kubernetes-the-hard-way-on-azure


https://itnext.io/cks-exam-series-1-create-cluster-security-best-practices-50e35aaa67ae

https://github.com/pksheldon4/cks-cluster

https://itnext.io/kubernetes-explained-deep-enough-1ea2c6821501


https://github.com/salaxander/kubernetes-the-hard-way/blob/master/docs/03-compute-resources.md


