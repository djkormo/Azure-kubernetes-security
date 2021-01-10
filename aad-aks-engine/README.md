

curl -o get-akse.sh https://raw.githubusercontent.com/Azure/aks-engine/master/scripts/get-akse.sh
chmod 700 get-akse.sh
./get-akse.sh

On Azure cloud shell

change 


AKSE_INSTALL_DIR:="/usr/local/bundle/bin"}"

to 

AKSE_INSTALL_DIR:="$HOME/bin"

cd $HOME/bin/

chmod 700 $HOME/bin/aks-engine

cd install/

$HOME/bin/aks-engine deploy --dns-prefix contoso-apple \
    --resource-group aks-engine-rg \
    --location northeurope \
    --api-model kubernetes-calico-azure.json \
    --auto-suffix





Literature:

https://github.com/Azure/aks-engine/blob/master/docs/tutorials/quickstart.md

https://github.com/Azure/aks-engine/blob/master/docs/topics/aad.md


