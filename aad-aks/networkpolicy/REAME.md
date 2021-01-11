```
kubectl gadget deploy > deploy-gadget.yaml
```

```
kubectl appy -f  deploy-gadget.yaml
```
<pre>
serviceaccount/gadget created
clusterrolebinding.rbac.authorization.k8s.io/gadget created
daemonset.apps/gadget created
</pre>
```
kubectl gadget network-policy monitor \
        --namespaces beta \
        --output ./beta-networktrace.log
```

```
kubectl gadget network-policy report \
        --input ./beta-networktrace.log > beta-generated-network-policy.yaml 
```

k kubectl -f  beta-generated-network-policy.yaml           



Literature:
https://kinvolk.io/blog/2020/03/writing-kubernetes-network-policies-with-inspektor-gadgets-network-policy-advisor/

