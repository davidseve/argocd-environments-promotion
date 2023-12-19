export HTPASSWD_FILE=/tmp/htpasswd

htpasswd -c -B -b $HTPASSWD_FILE user1 user1
htpasswd -b $HTPASSWD_FILE user2 user2


oc get secrets htpass-secret -n openshift-config -ojsonpath='{.data.htpasswd}' | base64 -d >> $HTPASSWD_FILE  

oc create secret generic htpass-secret --from-file=$HTPASSWD_FILE -n openshift-config --dry-run=client -o yaml > /tmp/htpass-secret.yaml
oc replace -f /tmp/htpass-secret.yaml
