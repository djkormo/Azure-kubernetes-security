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

