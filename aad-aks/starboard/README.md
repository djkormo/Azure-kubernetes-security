```
kubectl starboard init -v 3
```

```
kubectl starboard config
```

```
kubectl get deploy -n beta
```
<pre>
NAME                    READY   UP-TO-DATE   AVAILABLE   AGE
adservice               1/1     1            1           19m
cartservice             1/1     1            1           19m
checkoutservice         1/1     1            1           19m
currencyservice         1/1     1            1           19m
emailservice            1/1     1            1           19m
frontend                1/1     1            1           19m
loadgenerator           1/1     1            1           19m
paymentservice          1/1     1            1           19m
productcatalogservice   1/1     1            1           19m
recommendationservice   1/1     1            1           19m
redis-cart              1/1     1            1           19m
shippingservice         1/1     1            1           19m
</pre>

```
kubectl starboard scan vulnerabilityreports deploy/shippingservice -n beta  --delete-scan-job=false
kubectl starboard scan vulnerabilityreports deploy/frontend -n beta --delete-scan-job=false
```
```
k get job -n starboard
```
<pre>
NAME                                   COMPLETIONS   DURATION   AGE
443c809c-fee0-40ed-8a01-bd70c29304dd   1/1           26s        77s
d4b6904b-2ef8-4f88-805e-97f6f9cfbce6   1/1           30s        48s
</pre>

```
kubectl  get vulns  -n beta
```
<pre>
NAME                                REPOSITORY                                          TAG      SCANNER   AGE
deployment-frontend-server          google-samples/microservices-demo/frontend          v0.2.1   Trivy     26s
deployment-shippingservice-server   google-samples/microservices-demo/shippingservice   v0.2.1   Trivy     3m11s
</pre>

```
kubectl describe  $(kubectl get jobs -n starboard -o name) -n starboard
```

```
kubectl  get vulns  -n beta -o yaml | grep "vulnerabilities:" -A10
```