
Creating AKS cluster with AAD integration

```
bash aks-network-policy-calico-install.bash -n aks-security2020 -g aks-rg -l northeurope -o create
```

debug mode

bash -x aks-network-policy-calico-install.bash -n aks-security2020 -g aks-rg -l northeurope -o create

```
bash aks-network-policy-calico-install.bash -n aks-security2020 -g aks-rg -l northeurope -o stop
```

```
bash aks-network-policy-calico-install.bash -n aks-security2020 -g aks-rg -l northeurope -o start
```

```
bash aks-network-policy-calico-install.bash -n aks-security2020 -g aks-rg -l northeurope -o status
```

```
bash aks-network-policy-calico-install.bash -n aks-security2020 -g aks-rg -l northeurope -o delete
```

Download cli for kubernetes

```
az aks install-cli
```

Download kubernetes context file

```
az aks get-credentials --name aks-security2020  --resource-group aks-rg 
```

Trying to get information on kubernetes nodes

```
kubectl get nodes  
```

Permission testing

```
kubectl auth can-i create deployments --namespace default

kubectl auth can-i list nodes --namespace default

kubectl auth can-i list secrets --namespace default

```



Let's deploy sample applications

kubectl create ns alpha

kubectl apply -f https://k8s.io/examples/application/guestbook/redis-master-deployment.yaml -n alpha

kubectl apply -f https://k8s.io/examples/application/guestbook/redis-master-service.yaml -n alpha

kubectl apply -f https://k8s.io/examples/application/guestbook/redis-slave-deployment.yaml -n alpha

kubectl apply -f https://k8s.io/examples/application/guestbook/redis-slave-service.yaml -n alpha

kubectl apply -f https://k8s.io/examples/application/guestbook/frontend-deployment.yaml -n alpha

kubectl apply -f https://k8s.io/examples/application/guestbook/frontend-service.yaml -n alpha

kubectl create ns beta

kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/microservices-demo/ccff406cdcd3e043b432fe99b4038d1b4699c702/release/kubernetes-manifests.yaml -n beta