#!/usr/bin/env bash

#./test.sh si release no github_pat_XXXXXXXXXXXXXXX PASSWORD https://api.cluster-XX.XX.XX.opentlc.com:6443 

./createUsersCRC.sh
#token needs:  Read and Write access to code, commit statuses, and pull requests
user=user1
token=$4
funcPull()
{
    pull_number=$(curl -H "Accept: application/vnd.github+json"   -H "Authorization: Bearer $token"   https://api.github.com/repos/davidseve/argocd-environments-promotion/pulls | jq -r '.[0].number')
    curl \
    -X PUT \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $token" \
    https://api.github.com/repos/davidseve/argocd-environments-promotion/pulls/$pull_number/merge \
    -d '{"commit_title":"Expand enum","commit_message":"Add a new value to the merge_method enum"}'
}

waitpodup(){
  x=1
  test=""
  while [ -z "${test}" ]
  do 
    echo "Waiting ${x} times for pod ${1} in ns ${2}" $(( x++ ))
    sleep 1 
    test=$(oc get po -n ${2} | grep ${1})
  done
}

waitoperatorpod() {
  NS=openshift-operators
  waitpodup $1 ${NS}
  oc get pods -n ${NS} | grep ${1} | awk '{print "oc wait --for condition=Ready -n '${NS}' pod/" $1 " --timeout 300s"}' | sh
}


# oc extract secret/openshift-gitops-cluster -n openshift-gitops --to=-
# Add Argo CD Git Webhook to make it faster

rm -rf /tmp/deployment
mkdir /tmp/deployment
cd /tmp/deployment

git clone https://github.com/davidseve/argocd-environments-promotion.git
cd argocd-environments-promotion
#To work with a branch that is not main. ./test.sh ghp_JGFDSFIGJSODIJGF no helm_base
if [ ${2:-no} != "no" ]
then
    git fetch
    git switch $2
fi
git checkout -b release
git push origin release

if [ ${3:-no} = "no" ]
then
    oc apply -f gitops/gitops-operator.yaml
    waitoperatorpod gitops

    sed -i "s/changeme_token/$4/g" blue-green-pipeline-environments/application-cluster-config.yaml
    sed -i 's/changeme_user/davidseve/g' blue-green-pipeline-environments/application-cluster-config.yaml
    sed -i 's/changeme_mail/davidseve@gmail.com/g' blue-green-pipeline-environments/application-cluster-config.yaml
    sed -i 's/changeme_repository/davidseve/g' blue-green-pipeline-environments/application-cluster-config.yaml

    #To work with a branch that is not main. ./test.sh ghp_JGFDSFIGJSODIJGF no helm_base
    if [ ${2:-no} != "no" ]
    then
        sed -i "s/HEAD/$2/g" blue-green-pipeline-environments/application-cluster-config.yaml
    fi

    oc apply -f blue-green-pipeline-environments/application-cluster-config.yaml --wait=true

    #First time we install operators take logger
    if [ ${1:-no} = "no" ]
    then
        sleep 1m
    else
        sleep 2m
    fi
fi




sed -i 's/change_me/davidseve/g' gitops/app-config/applicationset-shop.yaml
sed -i "s/user1/$user/g" gitops/app-config/applicationset-shop.yaml
sed -i "s/user1/$user/g" blue-green-pipeline-environments/pipelines/run-products-stage/*
sed -i "s/user1/$user/g" blue-green-pipeline-environments/pipelines/run-products-prod/*

oc login -u $user -p $user $5

oc apply -f gitops/app-config/applicationset-shop.yaml --wait=true
