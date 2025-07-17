#
# Modify and run the following to create the required password secret for the chart:
kubectl create secret generic sense-cred \
    --from-literal=tls-password='TLS_PASSWORD' \
    --from-literal=mysql-password='DB_PASSWORD' \
    --from-literal=mail-password='MAIL_PASSWORD'

#
# Modify and run the following to create the required password secret for the chart:
kubectl create secret generic sense-auth-cred \
    --from-literal=client='CLIENT' \
    --from-literal=client-secret='CLIENT_SECRET'

#
# Configure or download a valid JKS keystore and run the following to create the required keystore secret for the chart:
# kubectl delete secret sense-keystores
kubectl create secret generic sense-keystores --from-file=client.keystore
