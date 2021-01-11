 ### create john service account in beta namespace

```bash
bash  create-serviceaccount-per-namespace.bash  -u john -n beta -l VIEW
```
or

```bash
bash  create-serviceaccount-per-namespace.bash  -u john -n beta -l ADMIN
```

### create config file for user john in beta namespace

```bash
bash  create-config-per-namespace.bash  -u john -n beta
```
