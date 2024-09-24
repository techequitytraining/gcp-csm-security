#!/bin/bash
#
# Copyright 2024 Tech Equity Cloud Services Ltd
# 
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
# 
#       http://www.apache.org/licenses/LICENSE-2.0
# 
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
# 
#################################################################################
#####  Explore Istio Hipster Microservice Application in Google Cloud Shell #####
#################################################################################

# User prompt function
function ask_yes_or_no() {
    read -p "$1 ([y]yes to preview, [n]o to create, [d]del to delete): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        n|no)  echo "no" ;;
        d|del) echo "del" ;;
        *)     echo "yes" ;;
    esac
}

function ask_yes_or_no_proj() {
    read -p "$1 ([y]es to change, or any key to skip): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}

clear
MODE=1
export TRAINING_ORG_ID=1 # $(gcloud organizations list --format 'value(ID)' --filter="displayName:techequity.training" 2>/dev/null)
export ORG_ID=1 # $(gcloud projects get-ancestors $GCP_PROJECT --format 'value(ID)' 2>/dev/null | tail -1 )
export GCP_PROJECT=$(gcloud config list --format 'value(core.project)' 2>/dev/null)  

echo
echo
echo -e "                        👋  Welcome to Cloud Sandbox! 💻"
echo 
echo -e "              *** PLEASE WAIT WHILE LAB UTILITIES ARE INSTALLED ***"
sudo apt-get -qq install pv > /dev/null 2>&1
echo 
export SCRIPTPATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

mkdir -p `pwd`/gcp-csm-security > /dev/null 2>&1
export PROJDIR=`pwd`/gcp-csm-security
export SCRIPTNAME=gcp-csm-security.sh

if [ -f "$PROJDIR/.env" ]; then
    source $PROJDIR/.env
else
cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_REGION=europe-west4
export GCP_ZONE=europe-west4-b
export GCP_CLUSTER=gcp-gke-cluster
export ASM_VERSION=1.23.2-asm.2
export ASM_INSTALL_SCRIPT_VERSION=1.22
EOF
source $PROJDIR/.env
fi

export APPLICATION_NAMESPACE=hipster
export APPLICATION_NAME=hipster

# Display menu options
while :
do
clear
cat<<EOF
================================================================
Explore Hipster Shop Microservices Application using ASM 
----------------------------------------------------------------
Please enter number to select your choice:
 (1) Install tools
 (2) Enable APIs
 (3) Create GKE cluster
(4A) Install Managed Anthos Service Mesh
(4B) Install In-cluster Anthos Service Mesh
 (5) Deploy microservices application
 (6) Configure ingress with managed certificate
 (7) Explore ASM traffic management
 (8) Explore ASM security
 (9) Configure web security scanner
(10) Blacklist Cloud Shell IP
(11) Configure ingress with managed certificate and IAP
 (Q) Quit
---------------------------------------------------------------
EOF
echo "Steps performed${STEP}"
echo
echo "What additional step do you want to perform, e.g. enter 0 to select the execution mode?"
read
clear
case "${REPLY^^}" in

"0")
start=`date +%s`
source $PROJDIR/.env
echo
echo "Do you want to run script in preview mode?"
export ANSWER=$(ask_yes_or_no "Are you sure?")
cd $HOME
if [[ ! -z "$TRAINING_ORG_ID" ]]  &&  [[ $ORG_ID == "$TRAINING_ORG_ID" ]]; then
    export STEP="${STEP},0"
    MODE=1
    if [[ "yes" == $ANSWER ]]; then
        export STEP="${STEP},0i"
        MODE=1
        echo
        echo "*** Command preview mode is active ***" | pv -qL 100
    else 
        if [[ -f $PROJDIR/.${GCP_PROJECT}.json ]]; then
            echo 
            echo "*** Authenticating using service account key $PROJDIR/.${GCP_PROJECT}.json ***" | pv -qL 100
            echo "*** To use a different GCP project, delete the service account key ***" | pv -qL 100
        else
            while [[ -z "$PROJECT_ID" ]] || [[ "$GCP_PROJECT" != "$PROJECT_ID" ]]; do
                echo 
                echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
                gcloud auth login  --brief --quiet
                export ACCOUNT=$(gcloud config list account --format "value(core.account)")
                if [[ $ACCOUNT != "" ]]; then
                    echo
                    echo "Copy and paste a valid Google Cloud project ID below to confirm your choice:" | pv -qL 100
                    read GCP_PROJECT
                    gcloud config set project $GCP_PROJECT --quiet 2>/dev/null
                    sleep 3
                    export PROJECT_ID=$(gcloud projects list --filter $GCP_PROJECT --format 'value(PROJECT_ID)' 2>/dev/null)
                fi
            done
            gcloud iam service-accounts delete ${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com --quiet 2>/dev/null
            sleep 2
            gcloud --project $GCP_PROJECT iam service-accounts create ${GCP_PROJECT} 2>/dev/null
            gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner > /dev/null 2>&1
            gcloud --project $GCP_PROJECT iam service-accounts keys create $PROJDIR/.${GCP_PROJECT}.json --iam-account=${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com 2>/dev/null
            gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
        fi
        export GOOGLE_APPLICATION_CREDENTIALS=$PROJDIR/.${GCP_PROJECT}.json
        cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_REGION=$GCP_REGION
export GCP_CLUSTER=$GCP_CLUSTER
export GCP_ZONE=$GCP_ZONE
export ASM_VERSION=$ASM_VERSION
export ASM_INSTALL_SCRIPT_VERSION=$ASM_INSTALL_SCRIPT_VERSION
EOF
        gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
        echo
        echo "*** Google Cloud project is $GCP_PROJECT ***" | pv -qL 100
        echo "*** Google Cloud region is $GCP_REGION ***" | pv -qL 100
        echo "*** Google Cloud zone is $GCP_ZONE ***" | pv -qL 100
        echo "*** Google Cloud cluster is $GCP_CLUSTER ***" | pv -qL 100
        echo "*** Anthos Service Mesh version is $ASM_VERSION ***" | pv -qL 100
        echo "*** Anthos Service Mesh install script version is $ASM_INSTALL_SCRIPT_VERSION ***" | pv -qL 100
        echo
        echo "*** Update environment variables by modifying values in the file: ***" | pv -qL 100
        echo "*** $PROJDIR/.env ***" | pv -qL 100
        if [[ "no" == $ANSWER ]]; then
            MODE=2
            echo
            echo "*** Create mode is active ***" | pv -qL 100
        elif [[ "del" == $ANSWER ]]; then
            export STEP="${STEP},0"
            MODE=3
            echo
            echo "*** Resource delete mode is active ***" | pv -qL 100
        fi
    fi
else 
    if [[ "no" == $ANSWER ]] || [[ "del" == $ANSWER ]] ; then
        export STEP="${STEP},0"
        if [[ -f $SCRIPTPATH/.${SCRIPTNAME}.secret ]]; then
            echo
            unset password
            unset pass_var
            echo -n "Enter access code: " | pv -qL 100
            while IFS= read -p "$pass_var" -r -s -n 1 letter
            do
                if [[ $letter == $'\0' ]]
                then
                    break
                fi
                password=$password"$letter"
                pass_var="*"
            done
            while [[ -z "${password// }" ]]; do
                unset password
                unset pass_var
                echo
                echo -n "You must enter an access code to proceed: " | pv -qL 100
                while IFS= read -p "$pass_var" -r -s -n 1 letter
                do
                    if [[ $letter == $'\0' ]]
                    then
                        break
                    fi
                    password=$password"$letter"
                    pass_var="*"
                done
            done
            export PASSCODE=$(cat $SCRIPTPATH/.${SCRIPTNAME}.secret | openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 100000 -salt -pass pass:$password 2> /dev/null)
            if [[ $PASSCODE == 'AccessVerified' ]]; then
                MODE=2
                echo && echo
                echo "*** Access code is valid ***" | pv -qL 100
                if [[ -f $PROJDIR/.${GCP_PROJECT}.json ]]; then
                    echo 
                    echo "*** Authenticating using service account key $PROJDIR/.${GCP_PROJECT}.json ***" | pv -qL 100
                    echo "*** To use a different GCP project, delete the service account key ***" | pv -qL 100
                else
                    while [[ -z "$PROJECT_ID" ]] || [[ "$GCP_PROJECT" != "$PROJECT_ID" ]]; do
                        echo 
                        echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
                        gcloud auth login  --brief --quiet
                        export ACCOUNT=$(gcloud config list account --format "value(core.account)")
                        if [[ $ACCOUNT != "" ]]; then
                            echo
                            echo "Copy and paste a valid Google Cloud project ID below to confirm your choice:" | pv -qL 100
                            read GCP_PROJECT
                            gcloud config set project $GCP_PROJECT --quiet 2>/dev/null
                            sleep 3
                            export PROJECT_ID=$(gcloud projects list --filter $GCP_PROJECT --format 'value(PROJECT_ID)' 2>/dev/null)
                        fi
                    done
                    gcloud iam service-accounts delete ${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com --quiet 2>/dev/null
                    sleep 2
                    gcloud --project $GCP_PROJECT iam service-accounts create ${GCP_PROJECT} 2>/dev/null
                    gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner > /dev/null 2>&1
                    gcloud --project $GCP_PROJECT iam service-accounts keys create $PROJDIR/.${GCP_PROJECT}.json --iam-account=${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com 2>/dev/null
                    gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
                fi
                export GOOGLE_APPLICATION_CREDENTIALS=$PROJDIR/.${GCP_PROJECT}.json
                cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_REGION=$GCP_REGION
export GCP_ZONE=$GCP_ZONE
export GCP_CLUSTER=$GCP_CLUSTER
export ASM_VERSION=$ASM_VERSION
export ASM_INSTALL_SCRIPT_VERSION=$ASM_INSTALL_SCRIPT_VERSION
EOF
                gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
                echo
                echo "*** Google Cloud project is $GCP_PROJECT ***" | pv -qL 100
                echo "*** Google Cloud region is $GCP_REGION ***" | pv -qL 100
                echo "*** Google Cloud zone is $GCP_ZONE ***" | pv -qL 100
                echo "*** Google Cloud cluster is $GCP_CLUSTER ***" | pv -qL 100
                echo "*** Anthos Service Mesh version is $ASM_VERSION ***" | pv -qL 100
                echo "*** Anthos Service Mesh install script version is $ASM_INSTALL_SCRIPT_VERSION ***" | pv -qL 100
                echo
                echo "*** Update environment variables by modifying values in the file: ***" | pv -qL 100
                echo "*** $PROJDIR/.env ***" | pv -qL 100
                if [[ "no" == $ANSWER ]]; then
                    MODE=2
                    echo
                    echo "*** Create mode is active ***" | pv -qL 100
                elif [[ "del" == $ANSWER ]]; then
                    export STEP="${STEP},0"
                    MODE=3
                    echo
                    echo "*** Resource delete mode is active ***" | pv -qL 100
                fi
            else
                echo && echo
                echo "*** Access code is invalid ***" | pv -qL 100
                echo "*** You can use this script in our Google Cloud Sandbox without an access code ***" | pv -qL 100
                echo "*** Contact support@techequity.cloud for assistance ***" | pv -qL 100
                echo
                echo "*** Command preview mode is active ***" | pv -qL 100
            fi
        else
            echo
            echo "*** You can use this script in our Google Cloud Sandbox without an access code ***" | pv -qL 100
            echo "*** Contact support@techequity.cloud for assistance ***" | pv -qL 100
            echo
            echo "*** Command preview mode is active ***" | pv -qL 100
        fi
    else
        export STEP="${STEP},0i"
        MODE=1
        echo
        echo "*** Command preview mode is active ***" | pv -qL 100
    fi
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"1")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},1i"
    echo
    echo "$ curl https://storage.googleapis.com/csm-artifacts/asm/asmcli_\${ASM_INSTALL_SCRIPT_VERSION} > \$PROJDIR/asmcli # to download script" | pv -qL 100
    echo
    echo "$ git clone https://github.com/GoogleCloudPlatform/anthos-service-mesh-packages.git /tmp/anthos-service-mesh-packages # to clone repo" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},1"
    echo
    echo "$ curl https://storage.googleapis.com/csm-artifacts/asm/asmcli_${ASM_INSTALL_SCRIPT_VERSION} > $PROJDIR/asmcli # to download script" | pv -qL 100
    curl https://storage.googleapis.com/csm-artifacts/asm/asmcli_${ASM_INSTALL_SCRIPT_VERSION} > $PROJDIR/asmcli
    echo
    echo "$ chmod +x $PROJDIR/asmcli # to make the script executable" | pv -qL 100
    chmod +x $PROJDIR/asmcli
    echo
    rm -rf /tmp/anthos-service-mesh-packages
    echo "$ git clone https://github.com/GoogleCloudPlatform/anthos-service-mesh-packages.git /tmp/anthos-service-mesh-packages # to clone repo" | pv -qL 100
    git clone https://github.com/GoogleCloudPlatform/anthos-service-mesh-packages.git /tmp/anthos-service-mesh-packages
    echo
    echo "$ cp -rf /tmp/anthos-service-mesh-packages $PROJDIR # to copy files"
    cp -rf /tmp/anthos-service-mesh-packages $PROJDIR
    rm -rf /tmp/anthos-service-mesh-packages
    echo
    rm -rf /tmp/istio-samples
    echo "$ git clone https://github.com/GoogleCloudPlatform/istio-samples.git /tmp/istio-samples # to clone repo" | pv -qL 100
    git clone https://github.com/GoogleCloudPlatform/istio-samples.git /tmp/istio-samples
    echo
    echo "$ cp -rf /tmp/istio-samples $PROJDIR # to copy files"
    cp -rf /tmp/istio-samples $PROJDIR
    rm -rf /tmp/istio-samples
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},1x"
    echo
    echo "$ rm -rf $PROJDIR # to delete files" | pv -qL 100
else
    export STEP="${STEP},1i"
    echo
    echo "1. Download ASM script" | pv -qL 100
    echo "2. Clone directory to download ASM package operators" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"2")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},2i"
    echo
    echo "$ gcloud --project \$GCP_PROJECT services enable container.googleapis.com compute.googleapis.com monitoring.googleapis.com logging.googleapis.com cloudtrace.googleapis.com meshca.googleapis.com mesh.googleapis.com meshconfig.googleapis.com iamcredentials.googleapis.com anthos.googleapis.com anthosgke.googleapis.com gkeconnect.googleapis.com gkehub.googleapis.com cloudresourcemanager.googleapis.com iap.googleapis.com websecurityscanner.googleapis.com opsconfigmonitoring.googleapis.com kubernetesmetadata.googleapis.com # to enable APIs" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},2"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    echo
    echo "$ gcloud --project $GCP_PROJECT services enable container.googleapis.com compute.googleapis.com monitoring.googleapis.com logging.googleapis.com cloudtrace.googleapis.com meshca.googleapis.com mesh.googleapis.com meshconfig.googleapis.com iamcredentials.googleapis.com anthos.googleapis.com anthosgke.googleapis.com gkeconnect.googleapis.com gkehub.googleapis.com cloudresourcemanager.googleapis.com iap.googleapis.com websecurityscanner.googleapis.com opsconfigmonitoring.googleapis.com kubernetesmetadata.googleapis.com # to enable APIs" | pv -qL 100
    gcloud --project $GCP_PROJECT services enable container.googleapis.com compute.googleapis.com monitoring.googleapis.com logging.googleapis.com cloudtrace.googleapis.com meshca.googleapis.com mesh.googleapis.com meshconfig.googleapis.com iamcredentials.googleapis.com anthos.googleapis.com anthosgke.googleapis.com gkeconnect.googleapis.com gkehub.googleapis.com cloudresourcemanager.googleapis.com iap.googleapis.com websecurityscanner.googleapis.com opsconfigmonitoring.googleapis.com kubernetesmetadata.googleapis.com
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},2x"
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},2i"
    echo
    echo "1. Enable APIs" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"3")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},3i"
    echo
    echo "$ gcloud --project \$GCP_PROJECT beta container clusters create \$GCP_CLUSTER --zone \$GCP_ZONE --machine-type=e2-standard-4 --num-nodes=3 --gateway-api=standard --workload-pool=\${WORKLOAD_POOL} --labels=mesh_id=\${MESH_ID},location=\$GCP_REGION --spot --enable-autoscaling --min-nodes=3 --max-nodes=6 # to create cluster" | pv -qL 100
    echo      
    echo "$ gcloud --project \$GCP_PROJECT container clusters get-credentials \$GCP_CLUSTER --zone \$GCP_ZONE # to retrieve credentials for cluster" | pv -qL 100
    echo
    echo "$ kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=\"\$(gcloud config get-value core/account)\" # to enable user to set RBAC rules" | pv -qL 100
    echo
    echo "$ gcloud container fleet memberships register \$GCP_CLUSTER --gke-cluster=\$GCP_ZONE/\$GCP_CLUSTER --enable-workload-identity # to register cluster" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},3"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    export PROJECT_NUMBER=$(gcloud projects describe $GCP_PROJECT --format="value(projectNumber)")
    export MESH_ID="proj-${PROJECT_NUMBER}" # sets the mesh_id label on the cluster
    export WORKLOAD_POOL=${GCP_PROJECT}.svc.id.goog
    echo
    echo "$ gcloud --project $GCP_PROJECT beta container clusters create $GCP_CLUSTER --zone $GCP_ZONE --machine-type=e2-standard-4 --num-nodes=3 --gateway-api=standard --workload-pool=${WORKLOAD_POOL}--labels=mesh_id=${MESH_ID},location=$GCP_REGION --spot --enable-autoscaling --min-nodes=3 --max-nodes=6 # to create cluster" | pv -qL 100
    gcloud --project $GCP_PROJECT beta container clusters create $GCP_CLUSTER --zone $GCP_ZONE --machine-type=e2-standard-4 --num-nodes=3 --gateway-api=standard --workload-pool=${WORKLOAD_POOL} --labels=mesh_id=${MESH_ID},location=$GCP_REGION --spot --enable-autoscaling --min-nodes=3 --max-nodes=6 
    echo      
    echo "$ gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE # to retrieve credentials for cluster" | pv -qL 100
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE
    echo
    echo "$ kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=\"\$(gcloud config get-value core/account)\" # to enable user to set RBAC rules" | pv -qL 100
    kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user="$(gcloud config get-value core/account)"
    echo
    echo "$ gcloud container fleet memberships register $GCP_CLUSTER --gke-cluster=$GCP_ZONE/$GCP_CLUSTER --enable-workload-identity # to register cluster"
    gcloud container fleet memberships register $GCP_CLUSTER --gke-cluster=$GCP_ZONE/$GCP_CLUSTER --enable-workload-identity
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},3x"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    echo
    echo "$ gcloud --project $GCP_PROJECT beta container clusters delete $GCP_CLUSTER --zone $GCP_ZONE # to delete cluster" | pv -qL 100
    gcloud --project $GCP_PROJECT beta container clusters delete $GCP_CLUSTER --zone $GCP_ZONE
else
    export STEP="${STEP},3i"
    echo
    echo "1. Create GKE cluster" | pv -qL 100
    echo "2. Retrieve credentials for cluster" | pv -qL 100
    echo "3. Grant cluster admin priviledges to user" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"4A")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},4Ai"
    echo
    echo "$ \$PROJDIR/asmcli install --project_id \$GCP_PROJECT --cluster_name \$GCP_CLUSTER --cluster_location \$CLUSTER_LOCATION --fleet_id \$GCP_PROJECT --output_dir \$PROJDIR --managed --enable_all --ca mesh_ca # to install ASM" | pv -qL 100
    echo
    echo "$ cat <<EOF | kubectl apply -f -
apiVersion: v1
data:
  mesh: |-
    defaultConfig:
      tracing:
        stackdriver: {}
kind: ConfigMap
metadata:
  name: asm-managed
  namespace: istio-system
EOF" | pv -qL 100
    echo
    echo "$ kubectl create namespace \$APPLICATION_NAMESPACE # to create namespace" | pv -qL 100
    echo
    echo "$ kubectl label namespace \$APPLICATION_NAMESPACE istio.io/rev=\$ASM_REVISION --overwrite # to create ingress" | pv -qL 100
    echo
    echo "$ kubectl annotate --overwrite namespace default mesh.cloud.google.com/proxy='{\"managed\":\"false\"}' # to enable Google to manage data plane"
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},4A"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_ZONE}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE > /dev/null 2>&1 
    export CLUSTER_LOCATION=$GCP_ZONE
    echo
    echo "$ gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE # to retrieve the credentials for cluster" | pv -qL 100
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE
    echo
    echo "$ $PROJDIR/asmcli install --project_id $GCP_PROJECT --cluster_name $GCP_CLUSTER --cluster_location $CLUSTER_LOCATION --fleet_id $GCP_PROJECT --output_dir $PROJDIR --managed --enable_all --ca mesh_ca # to install ASM" | pv -qL 100
    $PROJDIR/asmcli install --project_id $GCP_PROJECT --cluster_name $GCP_CLUSTER --cluster_location $CLUSTER_LOCATION --fleet_id $GCP_PROJECT --output_dir $PROJDIR --managed --enable_all --ca mesh_ca
    echo
    echo "$ cat <<EOF | kubectl apply -f -
apiVersion: v1
data:
  mesh: |-
    defaultConfig:
      tracing:
        stackdriver: {}
kind: ConfigMap
metadata:
  name: asm-managed
  namespace: istio-system
EOF" | pv -qL 100
cat <<EOF | kubectl apply -f -
apiVersion: v1
data:
  mesh: |-
    defaultConfig:
      tracing:
        stackdriver: {}
kind: ConfigMap
metadata:
  name: asm-managed
  namespace: istio-system
EOF
    echo
    echo "$ kubectl create namespace $APPLICATION_NAMESPACE # to create namespace" | pv -qL 100
    kubectl create namespace $APPLICATION_NAMESPACE
    echo
    echo "$ kubectl label namespace $APPLICATION_NAMESPACE istio.io/rev=asm-managed --overwrite # to label namespace" | pv -qL 100
    echo
    kubectl label namespace $APPLICATION_NAMESPACE istio.io/rev=asm-managed --overwrite
    echo
    echo "$ kubectl annotate --overwrite namespace $APPLICATION_NAMESPACE mesh.cloud.google.com/proxy='{\"managed\":\"true\"}' # to enable Google to manage data plane"
    kubectl annotate --overwrite namespace $APPLICATION_NAMESPACE mesh.cloud.google.com/proxy='{"managed":"true"}'
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},4Ax"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_ZONE}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE > /dev/null 2>&1 
    export CLUSTER_LOCATION=$GCP_ZONE
    echo
    echo "$ kubectl label namespace $APPLICATION_NAMESPACE istio.io/rev # to remove labels" | pv -qL 100
    kubectl label namespace $APPLICATION_NAMESPACE istio.io/rev-
    echo
    echo "$ kubectl delete validatingwebhookconfiguration,mutatingwebhookconfiguration -l operator.istio.io/component=Pilot # to remove webhooks" | pv -qL 100
    kubectl delete validatingwebhookconfiguration,mutatingwebhookconfiguration -l operator.istio.io/component=Pilot
    echo
    echo "$ $PROJDIR/istio-$ASM_VERSION/bin/istioctl x uninstall --purge # to remove the in-cluster control plane" | pv -qL 100
    $PROJDIR/istio-$ASM_VERSION/bin/istioctl x uninstall --purge
    echo && echo
    echo "$  kubectl delete namespace istio-system asm-system --ignore-not-found=true # to remove namespace" | pv -qL 100
     kubectl delete namespace istio-system asm-system --ignore-not-found=true
else
    export STEP="${STEP},4Ai"
    echo
    echo "1. Retrieve the credentials for cluster" | pv -qL 100
    echo "2. Configure Istio Operator" | pv -qL 100
    echo "3. Install Anthos Service Mesh" | pv -qL 100
    echo "4. Create and label namespace" | pv -qL 100
    echo "5. Enable in-cluster control plane" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"4B")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},4Bi"
    echo
    echo "$ gcloud --project \$GCP_PROJECT container clusters get-credentials \$GCP_CLUSTER --zone \$GCP_ZONE # to retrieve the credentials for cluster" | pv -qL 100
    echo
    echo "$ cat > \$PROJDIR/tracing.yaml <<EOF
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  meshConfig:
    enableTracing: true
  values:
    global:
      proxy:
        tracer: stackdriver
EOF" | pv -qL 100
    echo
    echo "$ \$PROJDIR/asmcli install --project_id \$GCP_PROJECT --cluster_name \$GCP_CLUSTER --cluster_location \$CLUSTER_LOCATION --fleet_id \$GCP_PROJECT --output_dir \$PROJDIR --enable_all --ca mesh_ca --custom_overlay \$PROJDIR/tracing.yaml --custom_overlay \$PROJDIR/anthos-service-mesh-packages/asm/istio/options/iap-operator.yaml # to install ASM" | pv -qL 100
    echo
    echo "$ kubectl create namespace \$APPLICATION_NAMESPACE # to create namespace" | pv -qL 100
    echo
    echo "$ kubectl label namespace \$APPLICATION_NAMESPACE istio.io/rev=\$ASM_REVISION --overwrite # to create ingress" | pv -qL 100
    echo
    echo "$ kubectl annotate --overwrite namespace \$APPLICATION_NAMESPACE mesh.cloud.google.com/proxy='{\"managed\":\"false\"}' # to enable Google to manage data plane"
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},4B"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_ZONE}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE > /dev/null 2>&1 
    export CLUSTER_LOCATION=$GCP_ZONE
    echo
    echo "$ gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE # to retrieve the credentials for cluster" | pv -qL 100
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE
    echo
    echo "$ cat > $PROJDIR/tracing.yaml <<EOF
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  meshConfig:
    enableTracing: true
  values:
    global:
      proxy:
        tracer: stackdriver
EOF" | pv -qL 100
cat > $PROJDIR/tracing.yaml <<EOF
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  meshConfig:
    enableTracing: true
  values:
    global:
      proxy:
        tracer: stackdriver
EOF
    echo
    sudo apt-get install ncat -y > /dev/null 2>&1 
    sudo rm -rf $PROJDIR/.asm_version
    echo "$ $PROJDIR/asmcli install --project_id $GCP_PROJECT --cluster_name $GCP_CLUSTER --cluster_location $CLUSTER_LOCATION --fleet_id $GCP_PROJECT --output_dir $PROJDIR --enable_all --ca mesh_ca --custom_overlay $PROJDIR/tracing.yaml --custom_overlay $PROJDIR/anthos-service-mesh-packages/asm/istio/options/iap-operator.yaml --option legacy-default-ingressgateway # to install ASM" | pv -qL 100
    $PROJDIR/asmcli install --project_id $GCP_PROJECT --cluster_name $GCP_CLUSTER --cluster_location $CLUSTER_LOCATION --fleet_id $GCP_PROJECT --output_dir $PROJDIR --enable_all --ca mesh_ca --custom_overlay $PROJDIR/tracing.yaml --custom_overlay $PROJDIR/anthos-service-mesh-packages/asm/istio/options/iap-operator.yaml --option legacy-default-ingressgateway
    echo
    echo "$ kubectl create namespace $APPLICATION_NAMESPACE # to create namespace" | pv -qL 100
    kubectl create namespace $APPLICATION_NAMESPACE
    export ASM_REVISION=$(kubectl get deploy -n istio-system -l app=istiod -o jsonpath={.items[*].metadata.labels.'istio\.io\/rev'}'{"\n"}')
    echo
    echo "$ kubectl label namespace $APPLICATION_NAMESPACE istio.io/rev=$ASM_REVISION --overwrite # to label namespace" | pv -qL 100
    kubectl label namespace $APPLICATION_NAMESPACE istio.io/rev=$ASM_REVISION --overwrite
    echo
    echo "$ kubectl annotate --overwrite namespace $APPLICATION_NAMESPACE mesh.cloud.google.com/proxy='{\"managed\":\"false\"}' # to enable Google to manage data plane"
    kubectl annotate --overwrite namespace $APPLICATION_NAMESPACE mesh.cloud.google.com/proxy='{"managed":"false"}'
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},4Bx"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_ZONE}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE > /dev/null 2>&1 
    export CLUSTER_LOCATION=$GCP_ZONE
    echo
    echo "$ kubectl label namespace $APPLICATION_NAMESPACE istio.io/rev # to remove labels" | pv -qL 100
    kubectl label namespace $APPLICATION_NAMESPACE istio.io/rev-
    echo
    echo "$ kubectl delete validatingwebhookconfiguration,mutatingwebhookconfiguration -l operator.istio.io/component=Pilot # to remove webhooks" | pv -qL 100
    kubectl delete validatingwebhookconfiguration,mutatingwebhookconfiguration -l operator.istio.io/component=Pilot
    echo
    echo "$ $PROJDIR/istio-$ASM_VERSION/bin/istioctl x uninstall --purge # to remove the in-cluster control plane" | pv -qL 100
    $PROJDIR/istio-$ASM_VERSION/bin/istioctl x uninstall --purge
    echo && echo
    echo "$  kubectl delete namespace istio-system asm-system --ignore-not-found=true # to remove namespace" | pv -qL 100
     kubectl delete namespace istio-system asm-system --ignore-not-found=true
else
    export STEP="${STEP},4Bi"
    echo
    echo "1. Retrieve the credentials for cluster" | pv -qL 100
    echo "2. Configure Istio Operator" | pv -qL 100
    echo "3. Install Anthos Service Mesh" | pv -qL 100
    echo "4. Create and label namespace" | pv -qL 100
    echo "5. Enable in-cluster control plane" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"5")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},5i"
    echo
    echo "$ kubectl create namespace \$APPLICATION_NAMESPACE # to create namespace" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE apply -f \$PROJDIR/istio-manifests.yaml # to apply manifests" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE apply -f \$PROJDIR/kubernetes-manifests.yaml # to apply manifests" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},5"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_ZONE}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE > /dev/null 2>&1 
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/microservices-demo/master/release/kubernetes-manifests.yaml # to deploy application" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/microservices-demo/master/release/kubernetes-manifests.yaml
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/microservices-demo/master/release/istio-manifests.yaml # to configure gateway" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/microservices-demo/master/release/istio-manifests.yaml
    echo
    echo "$ kubectl wait --for=condition=available --timeout=600s deployment --all -n $APPLICATION_NAMESPACE # to wait for the deployment to finish" | pv -qL 100
    kubectl wait --for=condition=available --timeout=600s deployment --all -n $APPLICATION_NAMESPACE
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},5x"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_ZONE}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE > /dev/null 2>&1 
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE delete -f https://raw.githubusercontent.com/GoogleCloudPlatform/microservices-demo/master/release/kubernetes-manifests.yaml # to delete deploy application" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE delete -f https://raw.githubusercontent.com/GoogleCloudPlatform/microservices-demo/master/release/kubernetes-manifests.yaml
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE delete -f https://raw.githubusercontent.com/GoogleCloudPlatform/microservices-demo/master/release/istio-manifests.yaml # to delete gateway" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE delete -f https://raw.githubusercontent.com/GoogleCloudPlatform/microservices-demo/master/release/istio-manifests.yaml
else
    export STEP="${STEP},5i"
    echo
    echo "1. Apply manifests to configure Gateway, Virtual Service, Service Entry, Deployment and Services" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"6")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},6i"
    echo
    echo "$ gcloud --project \$GCP_PROJECT compute addresses create \${APPLICATION_NAME}-iap-global-ip --global # to create static load balancer IP" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE patch service/frontend -p '{\"spec\":{\"type\":\"NodePort\"}}' # to change service type" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE apply -f - <<EOF
apiVersion: networking.gke.io/v1
kind: ManagedCertificate
metadata:
  name: \${APPLICATION_NAME}-managedcert
spec:
  domains:
    - \${LBIP}.nip.io
EOF" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE apply -f - <<EOF
apiVersion: networking.gke.io/v1
kind: Ingress
metadata:
  name: \${APPLICATION_NAME}-ingress
  annotations:
    kubernetes.io/ingress.global-static-ip-name: \${APPLICATION_NAME}-iap-global-ip
    networking.gke.io/managed-certificates: \${APPLICATION_NAME}-managedcert
  labels:
    app: \${APPLICATION_NAME}-app
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 80
EOF" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},6"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_ZONE}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE > /dev/null 2>&1 
    echo
    echo "$ gcloud --project $GCP_PROJECT compute addresses create ${APPLICATION_NAME}-iap-global-ip --global # to create static load balancer IP" | pv -qL 100
    gcloud --project $GCP_PROJECT compute addresses create ${APPLICATION_NAME}-iap-global-ip --global
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE patch service/frontend -p '{\"spec\":{\"type\":\"NodePort\"}}' # to change service type" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE patch service/frontend -p '{"spec":{"type":"NodePort"}}'
    echo
    export LBIP=$(gcloud --project $GCP_PROJECT compute addresses list --filter "NAME:${APPLICATION_NAME}-iap-global-ip" --format="value(address)") > /dev/null 2>&1 # to get external static IP address
    echo "$ kubectl -n $APPLICATION_NAMESPACE apply -f - <<EOF
apiVersion: networking.gke.io/v1
kind: ManagedCertificate
metadata:
  name: ${APPLICATION_NAME}-managedcert
spec:
  domains:
    - ${LBIP}.nip.io
EOF" | pv -qL 100
kubectl -n $APPLICATION_NAMESPACE apply -f - <<EOF
apiVersion: networking.gke.io/v1
kind: ManagedCertificate
metadata:
  name: ${APPLICATION_NAME}-managedcert
spec:
  domains:
    - ${LBIP}.nip.io
EOF
    echo
    echo "$ kubectl $APPLICATION_NAMESPACE apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${APPLICATION_NAME}-ingress
  annotations:
    kubernetes.io/ingress.global-static-ip-name: ${APPLICATION_NAME}-iap-global-ip
    networking.gke.io/managed-certificates: ${APPLICATION_NAME}-managedcert
  labels:
    app: ${APPLICATION_NAME}-app
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 80
EOF" | pv -qL 100
kubectl -n $APPLICATION_NAMESPACE apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${APPLICATION_NAME}-ingress
  annotations:
    kubernetes.io/ingress.global-static-ip-name: ${APPLICATION_NAME}-iap-global-ip
    networking.gke.io/managed-certificates: ${APPLICATION_NAME}-managedcert
  labels:
    app: ${APPLICATION_NAME}-app
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 80
EOF
    echo
    echo "Application URL is https://${LBIP}.nip.io/" | pv -qL 100
    echo "It may take up to 10 mins for the Ingress to be configured." | pv -qL 100
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},6x"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_ZONE}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE > /dev/null 2>&1 
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE delete Ingress ${APPLICATION_NAME}-ingress # to delete ingress" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE delete Ingress ${APPLICATION_NAME}-ingress
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE delete ManagedCertificate ${APPLICATION_NAME}-managedcert # to delete ManagedCertificate" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE delete ManagedCertificate ${APPLICATION_NAME}-managedcert
    echo
    echo "$ gcloud --project $GCP_PROJECT compute addresses delete ${APPLICATION_NAME}-iap-global-ip --global # to delete static IP" | pv -qL 100
    gcloud --project $GCP_PROJECT compute addresses delete ${APPLICATION_NAME}-iap-global-ip --global
else
    export STEP="${STEP},6i"
    echo
    echo "1. Configure ManagedCertificate and Ingress" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"7")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},7i"
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE patch deployments/productcatalogservice -p '{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"version\":\"v1\"}}}}}' # to version service" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE apply -f \$PROJDIR/istio-samples/istio-canary-gke/canary/destinationrule.yaml # to set routing of requests between the service versions" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE apply -f \$PROJDIR/istio-samples/istio-canary-gke/canary/productcatalog-v2.yaml # to deploy service with high latency" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE apply -f \$PROJDIR/istio-samples/istio-canary-gke/canary/vs-split-traffic.yaml # to split product catalog traffic 75% to v1 and 25% to v2" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},7"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_ZONE}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE > /dev/null 2>&1 
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE patch deployments/productcatalogservice -p '{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"version\":\"v1\"}}}}}' # to version service" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE patch deployments/productcatalogservice -p '{"spec":{"template":{"metadata":{"labels":{"version":"v1"}}}}}'
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE apply -f $PROJDIR/istio-samples/istio-canary-gke/canary/destinationrule.yaml # to set routing of requests between the service versions" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE apply -f $PROJDIR/istio-samples/istio-canary-gke/canary/destinationrule.yaml
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE apply -f $PROJDIR/istio-samples/istio-canary-gke/canary/productcatalog-v2.yaml # to deploy service with high latency" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE apply -f $PROJDIR/istio-samples/istio-canary-gke/canary/productcatalog-v2.yaml
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE apply -f $PROJDIR/istio-samples/istio-canary-gke/canary/vs-split-traffic.yaml # to split product catalog traffic 75% to v1 and 25% to v2" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE apply -f $PROJDIR/istio-samples/istio-canary-gke/canary/vs-split-traffic.yaml
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***' | pv -qL 100 
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE delete -f $PROJDIR/istio-samples/istio-canary-gke/canary/destinationrule.yaml # to delete service routing rule" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE delete -f $PROJDIR/istio-samples/istio-canary-gke/canary/destinationrule.yaml
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE delete -f $PROJDIR/istio-samples/istio-canary-gke/canary/productcatalog-v2.yaml # to delete v2 service" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE delete -f $PROJDIR/istio-samples/istio-canary-gke/canary/productcatalog-v2.yaml
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE delete -f $PROJDIR/istio-samples/istio-canary-gke/canary/vs-split-traffic.yaml # to delete trffic splitting rule" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE delete -f $PROJDIR/istio-samples/istio-canary-gke/canary/vs-split-traffic.yaml
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},7x"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_ZONE}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE > /dev/null 2>&1 
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},7i"
    echo
    echo "1. Configure virtual service and destination rules" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"8")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},8i"
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE exec \$(kubectl -n \$APPLICATION_NAMESPACE get pod -l app=productcatalogservice -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://frontend:80/ -o /dev/null -s -w '%{http_code}\n' # to send HTTP request from productcatalogservice to frontend service" | pv -qL 100
    echo
    echo "$ kubectl apply -n \$APPLICATION_NAMESPACE -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: frontend
spec:
  selector:
    matchLabels:
      app: frontend
  mtls:
    mode: STRICT # to strictly enforce mTLS on frontend microservice
EOF" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE exec \$(kubectl -n \$APPLICATION_NAMESPACE get pod -l app=productcatalogservice -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://frontend:80/ -o /dev/null -s -w '%{http_code}\n' # to send HTTP request from productcatalogservice to frontend service" | pv -qL 100
    echo
    echo "$ kubectl apply -n \$APPLICATION_NAMESPACE -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: RequestAuthentication
metadata:
 name: frontend
spec:
  selector:
    matchLabels:
      app: frontend
  jwtRules:
  - issuer: testing@secure.istio.io
    jwksUri: https://raw.githubusercontent.com/istio/istio/release-1.5/security/tools/jwt/samples/jwks.json # to enforce end-user (origin) authentication for the frontend service, using JSON Web Tokens (JWT)
EOF" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE exec \$(kubectl -n \$APPLICATION_NAMESPACE get pod -l app=productcatalogservice -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://frontend:80/ -o /dev/null --header \"Authorization: Bearer \$TOKEN\" -s -w '%{http_code}\n' # to curl the frontend with a valid JWT" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE exec \$(kubectl -n \$APPLICATION_NAMESPACE get pod -l app=productcatalogservice -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://frontend:80/ -o /dev/null -s -w '%{http_code}\n' # to curl the frontend without a JWT" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE exec \$(kubectl -n \$APPLICATION_NAMESPACE get pod -l app=productcatalogservice -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://frontend:80/ -o /dev/null --header \"Authorization: Bearer helloworld\" -s -w '%{http_code}\n' # to curl the frontend with an invalid JWT" | pv -qL 100
    echo
    echo "$ kubectl apply -n \$APPLICATION_NAMESPACE -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: require-jwt
spec:
  selector:
    matchLabels:
      app: frontend
  action: ALLOW
  rules:
  - from:
    - source:
       requestPrincipals: [testing@secure.istio.io/testing@secure.istio.io] # to configure an authorization policy that requires a JWT on all requests
EOF" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE exec \$(kubectl -n \$APPLICATION_NAMESPACE get pod -l app=productcatalogservice -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://frontend:80/ -o /dev/null -s -w '%{http_code}\n' # to curl the frontend without a JWT" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE exec \$(kubectl -n \$APPLICATION_NAMESPACE get pod -l app=productcatalogservice -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://frontend:80/ -o /dev/null --header \"Authorization: Bearer \$TOKEN\" -s -w '%{http_code}\n' # to curl the frontend with a valid JWT" | pv -qL 100
    echo
    echo "$ kubectl apply -n \$APPLICATION_NAMESPACE -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: frontend
spec:
  selector:
    matchLabels:
      app: frontend
  rules:
  - when:
    - key: request.headers[hello]
      values: [world] # to only allowing requests to the frontend that have a specific HTTP header (hello:world)
EOF" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE exec \$(kubectl -n \$APPLICATION_NAMESPACE get pod -l app=productcatalogservice -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://frontend:80/ -o /dev/null -s -w '%{http_code}\n' # to curl the frontend without the hello header" | pv -qL 100 
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE exec \$(kubectl -n \$APPLICATION_NAMESPACE get pod -l app=productcatalogservice -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl --header \"hello:world\" http://frontend:80/ -o /dev/null -s -w '%{http_code}\n' # to curl the frontend with the hello:world header" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},8"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_ZONE}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE > /dev/null 2>&1 
    export INGRESS_HOST=$(kubectl -n hipster get service istio-gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
   echo
    echo "$ kubectl wait --for=condition=available --timeout=600s deployment --all -n $APPLICATION_NAMESPACE # to wait for the deployment to finish" | pv -qL 100
    kubectl wait --for=condition=available --timeout=600s deployment --all -n $APPLICATION_NAMESPACE
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE exec \$(kubectl -n $APPLICATION_NAMESPACE get pod -l app=productcatalogservice -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://frontend:80/ -o /dev/null -s -w '%{http_code}\n' # to send HTTP request from productcatalogservice to frontend service" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE exec $(kubectl -n $APPLICATION_NAMESPACE get pod -l app=productcatalogservice -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://frontend:80/ -o /dev/null -s -w '%{http_code}\n'
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl apply -n $APPLICATION_NAMESPACE -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: frontend
spec:
  selector:
    matchLabels:
      app: frontend
  mtls:
    mode: STRICT # to strictly enforce mTLS on frontend microservice
EOF" | pv -qL 100
kubectl apply -n $APPLICATION_NAMESPACE -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: frontend
spec:
  selector:
    matchLabels:
      app: frontend
  mtls:
    mode: STRICT # to strictly enforce mTLS on frontend microservice
EOF
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE exec \$(kubectl -n $APPLICATION_NAMESPACE get pod -l app=productcatalogservice -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://frontend:80/ -o /dev/null -s -w '%{http_code}\n' # to send HTTP request from productcatalogservice to frontend service" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE exec $(kubectl -n $APPLICATION_NAMESPACE get pod -l app=productcatalogservice -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://frontend:80/ -o /dev/null -s -w '%{http_code}\n'
    sleep 5
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE delete PeerAuthentication frontend # to delete configuration" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE delete PeerAuthentication frontend
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl apply -n $APPLICATION_NAMESPACE -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: RequestAuthentication
metadata:
 name: frontend
spec:
  selector:
    matchLabels:
      app: frontend
  jwtRules:
  - issuer: testing@secure.istio.io
    jwksUri: https://raw.githubusercontent.com/istio/istio/release-1.5/security/tools/jwt/samples/jwks.json # to enforce end-user (origin) authentication for the frontend service, using JSON Web Tokens (JWT)
EOF" | pv -qL 100
kubectl apply -n $APPLICATION_NAMESPACE -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: RequestAuthentication
metadata:
 name: frontend
spec:
  selector:
    matchLabels:
      app: frontend
  jwtRules:
  - issuer: testing@secure.istio.io
    jwksUri: https://raw.githubusercontent.com/istio/istio/release-1.5/security/tools/jwt/samples/jwks.json # to enforce end-user (origin) authentication for the frontend service, using JSON Web Tokens (JWT)
EOF
    echo
    echo "$ export TOKEN=\$(curl -k https://raw.githubusercontent.com/istio/istio/release-1.4/security/tools/jwt/samples/demo.jwt -s); echo \$TOKEN # to set a local TOKEN variable" | pv -qL 100
    export TOKEN=$(curl -k https://raw.githubusercontent.com/istio/istio/release-1.4/security/tools/jwt/samples/demo.jwt -s); echo $TOKEN
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE exec \$(kubectl -n $APPLICATION_NAMESPACE get pod -l app=productcatalogservice -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://frontend:80/ -o /dev/null --header \"Authorization: Bearer \$TOKEN\" -s -w '%{http_code}\n' # to curl the frontend with a valid JWT" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE exec $(kubectl -n $APPLICATION_NAMESPACE get pod -l app=productcatalogservice -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://frontend:80/ -o /dev/null --header "Authorization: Bearer $TOKEN" -s -w '%{http_code}\n'
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE exec \$(kubectl -n $APPLICATION_NAMESPACE get pod -l app=productcatalogservice -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://frontend:80/ -o /dev/null -s -w '%{http_code}\n' # to curl the frontend without a JWT" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE exec $(kubectl -n $APPLICATION_NAMESPACE get pod -l app=productcatalogservice -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://frontend:80/ -o /dev/null -s -w '%{http_code}\n'
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE exec \$(kubectl -n $APPLICATION_NAMESPACE get pod -l app=productcatalogservice -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://frontend:80/ -o /dev/null --header \"Authorization: Bearer helloworld\" -s -w '%{http_code}\n' # to curl the frontend with an invalid JWT" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE exec $(kubectl -n $APPLICATION_NAMESPACE get pod -l app=productcatalogservice -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://frontend:80/ -o /dev/null --header "Authorization: Bearer helloworld" -s -w '%{http_code}\n'
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl apply -n $APPLICATION_NAMESPACE -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: require-jwt
spec:
  selector:
    matchLabels:
      app: frontend
  action: ALLOW
  rules:
  - from:
    - source:
       requestPrincipals: [testing@secure.istio.io/testing@secure.istio.io] # to configure an authorization policy that requires a JWT on all requests
EOF" | pv -qL 100
kubectl apply -n $APPLICATION_NAMESPACE -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: require-jwt
spec:
  selector:
    matchLabels:
      app: frontend
  action: ALLOW
  rules:
  - from:
    - source:
       requestPrincipals: [testing@secure.istio.io/testing@secure.istio.io] # to configure an authorization policy that requires a JWT on all requests
EOF
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE exec \$(kubectl -n $APPLICATION_NAMESPACE get pod -l app=productcatalogservice -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://frontend:80/ -o /dev/null -s -w '%{http_code}\n' # to curl the frontend without a JWT" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE exec $(kubectl -n $APPLICATION_NAMESPACE get pod -l app=productcatalogservice -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://frontend:80/ -o /dev/null -s -w '%{http_code}\n'
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE exec \$(kubectl -n $APPLICATION_NAMESPACE get pod -l app=productcatalogservice -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://frontend:80/ -o /dev/null --header \"Authorization: Bearer \$TOKEN\" -s -w '%{http_code}\n' # to curl the frontend with a valid JWT" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE exec $(kubectl -n $APPLICATION_NAMESPACE get pod -l app=productcatalogservice -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://frontend:80/ -o /dev/null --header "Authorization: Bearer $TOKEN" -s -w '%{http_code}\n'
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl apply -n $APPLICATION_NAMESPACE -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: frontend
spec:
  selector:
    matchLabels:
      app: frontend
  rules:
  - when:
    - key: request.headers[hello]
      values: [world] # to only allowing requests to the frontend that have a specific HTTP header (hello:world)
EOF" | pv -qL 100
kubectl apply -n $APPLICATION_NAMESPACE -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: frontend
spec:
  selector:
    matchLabels:
      app: frontend
  rules:
  - when:
    - key: request.headers[hello]
      values: [world] # to only allowing requests to the frontend that have a specific HTTP header (hello:world)
EOF
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE exec \$(kubectl -n $APPLICATION_NAMESPACE get pod -l app=productcatalogservice -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://frontend:80/ -o /dev/null -s -w '%{http_code}\n' # to curl the frontend without the hello header" | pv -qL 100 
    kubectl -n $APPLICATION_NAMESPACE exec $(kubectl -n $APPLICATION_NAMESPACE get pod -l app=productcatalogservice -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl http://frontend:80/ -o /dev/null -s -w '%{http_code}\n'
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE exec \$(kubectl -n $APPLICATION_NAMESPACE get pod -l app=productcatalogservice -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl --header \"hello:world\" http://frontend:80/ -o /dev/null -s -w '%{http_code}\n' # to curl the frontend with the hello:world header" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE exec $(kubectl -n $APPLICATION_NAMESPACE get pod -l app=productcatalogservice -o jsonpath={.items..metadata.name}) -c istio-proxy -- curl --header "hello:world" http://frontend:80/ -o /dev/null -s -w '%{http_code}\n'
    echo
    echo "$ kubectl delete RequestAuthentication frontend -n $APPLICATION_NAMESPACE # to delete rule" | pv -qL 100
    kubectl delete RequestAuthentication frontend -n $APPLICATION_NAMESPACE
    echo
    echo "$ kubectl delete AuthorizationPolicy require-jwt -n $APPLICATION_NAMESPACE # to delete rule" | pv -qL 100
    kubectl delete AuthorizationPolicy require-jwt -n $APPLICATION_NAMESPACE
    echo
    echo "$ kubectl delete AuthorizationPolicy frontend -n $APPLICATION_NAMESPACE # to delete rule" | pv -qL 100
    kubectl delete AuthorizationPolicy frontend -n $APPLICATION_NAMESPACE
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},8x"
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},8i"
    echo
    echo "1. Configure PeerAuthentication, RequestAuthentication and AuthorizationPolicy" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"9")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},9i"
    echo
    echo "$ gcloud --project \$GCP_PROJECT alpha web-security-scanner scan-configs create --display-name=\${APPLICATION_NAME}-scan-config --starting-urls=http://\${LBIP}/ --schedule-interval-days=1 --schedule-next-start=\$(date -d '1 mins' -Is) # configure scan" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},9"
    echo
    export LBIP=$(gcloud --project $GCP_PROJECT compute addresses list --filter "NAME:${APPLICATION_NAME}-iap-global-ip" --format="value(address)") > /dev/null 2>&1 # to get external static IP address
    echo "$ gcloud --project $GCP_PROJECT alpha web-security-scanner scan-configs create --display-name=${APPLICATION_NAME}-scan-config --starting-urls=http://${LBIP}/ --schedule-interval-days=1 --schedule-next-start=$(date -d '1 mins' -Is) # configure scan" | pv -qL 100
    gcloud --project $GCP_PROJECT alpha web-security-scanner scan-configs create --display-name=${APPLICATION_NAME}-scan-config --starting-urls=http://${LBIP}/ --schedule-interval-days=1 --schedule-next-start=$(date -d '1 mins' -Is)
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},9x"
    echo
    export SCAN_CONFIG=$(gcloud --project qwiklabs-gcp-04-a8d14facaa81 alpha web-security-scanner scan-configs list --format="value(name)" --filter="displayName:${APPLICATION_NAME}-scan-config")
    echo "$ gcloud --project $GCP_PROJECT alpha web-security-scanner scan-configs delete $SCAN_CONFIG # to delete scan" | pv -qL 100
    gcloud --project $GCP_PROJECT alpha web-security-scanner scan-configs delete $SCAN_CONFIG

else
    export STEP="${STEP},9i"
    echo
    echo "1. Configure scan" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"10")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},10i"
    echo
    echo "$ gcloud --project \$GCP_PROJECT compute security-policies create denylist-siege # to create security policy" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT compute security-policies rules create 1000 --action deny-403 --security-policy denylist-siege --src-ip-ranges $IPV4 # to create rule" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT compute backend-services update \$BACKEND_SERVICE --security-policy=denylist-siege --global # to apply security policy to backend service" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},10"    
    echo
    echo "$ export IPV4=\$(dig +short myip.opendns.com @resolver1.opendns.com) # to set IP" | pv -qL 100
    export IPV4=$(dig +short myip.opendns.com @resolver1.opendns.com)
    echo
    echo "$ export LBIP=\$(gcloud --project $GCP_PROJECT compute addresses list --filter \"NAME:${APPLICATION_NAME}-iap-global-ip\" --format=\"value(address)\")  # to get load balancer IP" | pv -qL 100
    export LBIP=$(gcloud --project $GCP_PROJECT compute addresses list --filter "NAME:${APPLICATION_NAME}-iap-global-ip" --format="value(address)") > /dev/null 2>&1 # to get external static IP address
    export MANAGED_STATUS=$(gcloud compute ssl-certificates list --filter="managed.domains:${LBIP}.nip.io" --format 'value(MANAGED_STATUS)')
    while [[ ! "$MANAGED_STATUS" =~ ACTIVE ]]; do
        sleep 30
        echo
        echo "*** Managed SSL certificate status is $MANAGED_STATUS ***"
        export MANAGED_STATUS=$(gcloud compute ssl-certificates list --filter="managed.domains:${LBIP}.nip.io" --format 'value(MANAGED_STATUS)')
    done
    echo
    echo "$ export BACKEND_SERVICE=\$(gcloud --project $GCP_PROJECT compute url-maps list | grep ${APPLICATION_NAME}-ingress | awk '{print \$2}' | cut -d'/' -f 2) # to set backend service" | pv -qL 100
    export BACKEND_SERVICE=$(gcloud --project $GCP_PROJECT compute url-maps list | grep ${APPLICATION_NAME}-ingress | awk '{print $2}' | cut -d'/' -f 2) 
    echo
    echo "$ curl http://$LBIP | grep -o 'Online Boutique' # to request endpoint" | pv -qL 100
    curl http://$LBIP | grep -o 'Online Boutique'
    echo
    echo "$ gcloud --project $GCP_PROJECT compute security-policies create denylist-siege # to create security policy" | pv -qL 100
    gcloud --project $GCP_PROJECT compute security-policies create denylist-siege
    echo
    echo "$ gcloud --project $GCP_PROJECT compute security-policies rules create 1000 --action deny-403 --security-policy denylist-siege --src-ip-ranges $IPV4 # to create rule" | pv -qL 100
    gcloud --project $GCP_PROJECT compute security-policies rules create 1000 --action deny-403 --security-policy denylist-siege --src-ip-ranges $IPV4
    echo
    bash -c 'BACKEND=""; while [ -z \$BACKEND_SERVICE ]; do echo "Waiting for backend..."; BACKEND_SERVICE=$(gcloud --project $GCP_PROJECT compute url-maps list | grep NAME | rev | cut -d':' -f1 | rev | sed "s/ //g"); [ -z "$BACKEND_SERVICE" ] && sleep 10; done; echo "Backend ready: $BACKEND_SERVICE"'
    export BACKEND=$(gcloud --project $GCP_PROJECT compute url-maps list | grep $BACKEND_SERVICE | grep NAME | rev | cut -d':' -f1 | rev | sed 's/ //g')
    echo
    export BACKEND_SERVICE=$(gcloud --project $GCP_PROJECT compute url-maps describe ${BACKEND} --global | grep '^defaultService:' | rev | cut -d/ -f1 | rev) # to set the healthcheck 
    echo "$ gcloud --project $GCP_PROJECT compute backend-services update $BACKEND_SERVICE --security-policy=denylist-siege --global # to apply security policy to backend service" | pv -qL 100
    gcloud --project $GCP_PROJECT compute backend-services update $BACKEND_SERVICE --security-policy=denylist-siege --global
    sleep 15
    echo
    echo "$ curl http://$LBIP | grep -o 'Online Boutique' # to request endpoint" | pv -qL 100
    curl http://$LBIP | grep -o 'Online Boutique'
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},10x"
    echo
    echo "$ gcloud --project $GCP_PROJECT compute security-policies delete denylist-siege --global # to delete security policy" | pv -qL 100
    gcloud --project $GCP_PROJECT compute security-policies delete denylist-siege --global 
else
    export STEP="${STEP},10i"
    echo
    echo "1. Get load balancer IP" | pv -qL 100
    echo "2. Configure backend service" | pv -qL 100
    echo "3. Create security policy" | pv -qL 100
    echo "4. Create rule" | pv -qL 100
    echo "5. Apply security policy to backend service" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"11")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},11i"
    echo
    echo "$ gcloud --project \$GCP_PROJECT alpha iap oauth-brands create --application_title=\$APPLICATION_NAME --support_email=\$(gcloud config get-value core/account) # to create brand" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT alpha iap oauth-clients create \$BRAND_ID --display_name=\$APPLICATION_NAME # to create OAuth client" | pv -qL 100
    echo
    echo "$ kubectl create secret generic -n \$APPLICATION_NAMESPACE my-secret --from-literal=client_id=\$CLIENT_ID --from-literal=client_secret=\$CLIENT_SECRET # to create secret" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE apply -f - <<EOF
apiVersion: networking.gke.io/v1
kind: ManagedCertificate
metadata:
  name: \${APPLICATION_NAME}-managedcert
spec:
  domains:
    - \${LBIP}.nip.io
EOF" | pv -qL 100
    echo
    echo "$ cat <<EOF | kubectl apply -n \$APPLICATION_NAMESPACE -f -
apiVersion: cloud.google.com/v1
kind: BackendConfig
metadata:
  name: http-hc-config
spec:
  healthCheck:
    checkIntervalSec: 2
    timeoutSec: 1
    healthyThreshold: 1
    unhealthyThreshold: 10
    port: \${HC_INGRESS_PORT}
    type: HTTP
    requestPath: \${HC_INGRESS_PATH}
  iap:
    enabled: true
    oauthclientCredentials:
      secretName: my-secret
EOF" | pv -qL 100
    echo
    echo "$ kubectl annotate -n \$APPLICATION_NAMESPACE service/frontend --overwrite cloud.google.com/backend-config='{\"default\": \"http-hc-config\"}' cloud.google.com/neg='{\"ingress\":false}' # to annotate the service with BackendConfig" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: \${APPLICATION_NAME}-ingress
  annotations:
    kubernetes.io/ingress.global-static-ip-name: \${APPLICATION_NAME}-iap-global-ip
    networking.gke.io/managed-certificates: \${APPLICATION_NAME}-managedcert
  labels:
    app: \${APPLICATION_NAME}-app
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 80
EOF" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT projects add-iam-policy-binding \$GCP_PROJECT --member=user:\$(gcloud config get-value core/account) --role=roles/iap.httpsResourceAccessor # to grant Cloud IAP/IAP-Secured Web App User role" | pv -qL 40
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},11"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_ZONE}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE > /dev/null 2>&1 
    echo
    echo "$ export BRAND_NAME=\$(gcloud --project $GCP_PROJECT alpha iap oauth-brands list --format=\"value(name)\") # to get brand name" | pv -qL 100
    export BRAND_NAME=$(gcloud --project $GCP_PROJECT alpha iap oauth-brands list --format="value(name)") > /dev/null 2>&1
    echo
    echo "$ export BACKEND_SERVICE=\$(gcloud --project $GCP_PROJECT compute url-maps list | grep ${APPLICATION_NAME}-ingress | awk '{print \$2}' | cut -d'/' -f 2) # to set backend service" | pv -qL 100
    export BACKEND_SERVICE=$(gcloud --project $GCP_PROJECT compute url-maps list | grep ${APPLICATION_NAME}-ingress | awk '{print $2}' | cut -d'/' -f 2)
    if [ -z "$BRAND_NAME" ]
    then
        echo
        echo "$ gcloud --project $GCP_PROJECT alpha iap oauth-brands create --application_title=$APPLICATION_NAME --support_email=\$(gcloud config get-value core/account) # to create brand" | pv -qL 100
        gcloud --project $GCP_PROJECT alpha iap oauth-brands create --application_title=$APPLICATION_NAME --support_email=$(gcloud config get-value core/account)
        sleep 10
        echo
        echo "$ export BRAND_ID=\$(gcloud --project $GCP_PROJECT alpha iap oauth-brands list --format=\"value(name)\") # to set brand ID" | pv -qL 100
        export BRAND_ID=$(gcloud --project $GCP_PROJECT alpha iap oauth-brands list --format="value(name)") > /dev/null 2>&1
    else
        echo
        echo "$ export BRAND_ID=\$(gcloud --project $GCP_PROJECT alpha iap oauth-brands list --format=\"value(name)\") # to set brand ID" | pv -qL 100
        export BRAND_ID=$(gcloud --project $GCP_PROJECT alpha iap oauth-brands list --format="value(name)") > /dev/null 2>&1 # to set brand ID
    fi
    export CLIENT_LIST=$(gcloud --project $GCP_PROJECT alpha iap oauth-clients list $BRAND_ID) > /dev/null 2>&1
    if [ -z "$CLIENT_LIST" ]
    then
        echo
        echo "$ gcloud --project $GCP_PROJECT alpha iap oauth-clients create $BRAND_ID --display_name=$APPLICATION_NAME # to create OAuth client" | pv -qL 100
        gcloud --project $GCP_PROJECT alpha iap oauth-clients create $BRAND_ID --display_name=$APPLICATION_NAME
        sleep 10
        echo
        echo "$ export CLIENT_ID=\$(gcloud --project $GCP_PROJECT alpha iap oauth-clients list $BRAND_ID --format=\"value(name)\" | awk -F/ '{print \$NF}') # to set client ID" | pv -qL 100
        export CLIENT_ID=$(gcloud --project $GCP_PROJECT alpha iap oauth-clients list $BRAND_ID --format="value(name)" | awk -F/ '{print $NF}') > /dev/null 2>&1
        echo
        echo "$ export CLIENT_SECRET=\$(gcloud --project $GCP_PROJECT alpha iap oauth-clients list $BRAND_ID --format=\"value(secret)\") # to set secret" | pv -qL 100
        export CLIENT_SECRET=$(gcloud --project $GCP_PROJECT alpha iap oauth-clients list $BRAND_ID --format="value(secret)") > /dev/null 2>&1
    else
        echo
        echo "$ export CLIENT_ID=\$(gcloud --project $GCP_PROJECT alpha iap oauth-clients list $BRAND_ID --format=\"value(name)\" | awk -F/ '{print \$NF}') # to set client ID" | pv -qL 100
        export CLIENT_ID=$(gcloud --project $GCP_PROJECT alpha iap oauth-clients list $BRAND_ID --format="value(name)" | awk -F/ '{print $NF}') > /dev/null 2>&1
        echo
        echo "$ export CLIENT_SECRET=\$(gcloud --project $GCP_PROJECT alpha iap oauth-clients list $BRAND_ID --format=\"value(secret)\") # to set secret" | pv -qL 100
        export CLIENT_SECRET=$(gcloud --project $GCP_PROJECT alpha iap oauth-clients list $BRAND_ID --format="value(secret)") > /dev/null 2>&1
    fi
    echo
    echo "$ kubectl create secret generic -n $APPLICATION_NAMESPACE my-secret --from-literal=client_id=$CLIENT_ID --from-literal=client_secret=\$CLIENT_SECRET # to create secret" | pv -qL 100
    kubectl create secret generic -n $APPLICATION_NAMESPACE my-secret --from-literal=client_id=$CLIENT_ID --from-literal=client_secret=$CLIENT_SECRET
    echo
    echo "$ export LBIP=\$(gcloud --project $GCP_PROJECT compute addresses list --filter \"NAME:${APPLICATION_NAME}-iap-global-ip\" --format=\"value(address)\") # to get external static IP address" | pv -qL 100
    export LBIP=$(gcloud --project $GCP_PROJECT compute addresses list --filter "NAME:${APPLICATION_NAME}-iap-global-ip" --format="value(address)") > /dev/null 2>&1
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE apply -f - <<EOF
apiVersion: networking.gke.io/v1
kind: ManagedCertificate
metadata:
  name: ${APPLICATION_NAME}-managedcert
spec:
  domains:
    - ${LBIP}.nip.io
EOF" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE apply -f - <<EOF
apiVersion: networking.gke.io/v1
kind: ManagedCertificate
metadata:
  name: ${APPLICATION_NAME}-managedcert
spec:
  domains:
    - ${LBIP}.nip.io
EOF
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE patch service/frontend -p '{\"spec\":{\"type\":\"NodePort\"}}' # to change service type" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE patch service/frontend -p '{"spec":{"type":"NodePort"}}'
    sleep 5
    echo
    echo "$ export HC_INGRESS_PORT=\$(kubectl -n $APPLICATION_NAMESPACE get service frontend -o jsonpath='{.spec.ports[?(@.name==\"http\")].nodePort}') # to set healthcheck port of frontend" | pv -qL 100
    export HC_INGRESS_PORT=$(kubectl -n $APPLICATION_NAMESPACE get service frontend -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}') # to set healthcheck port of istio-ingress
    export HC_INGRESS_PATH="/"
    sleep 10
    echo
    echo "$ cat <<EOF | kubectl apply -n $APPLICATION_NAMESPACE -f -
apiVersion: cloud.google.com/v1
kind: BackendConfig
metadata:
  name: http-hc-config
spec:
  healthCheck:
    checkIntervalSec: 2
    timeoutSec: 1
    healthyThreshold: 1
    unhealthyThreshold: 10
    port: ${HC_INGRESS_PORT}
    type: HTTP
    requestPath: ${HC_INGRESS_PATH}
  iap:
    enabled: true
    oauthclientCredentials:
      secretName: my-secret
EOF" | pv -qL 100
    cat <<EOF | kubectl apply -n $APPLICATION_NAMESPACE -f -
apiVersion: cloud.google.com/v1
kind: BackendConfig
metadata:
  name: http-hc-config
spec:
  healthCheck:
    checkIntervalSec: 2
    timeoutSec: 1
    healthyThreshold: 1
    unhealthyThreshold: 10
    port: ${HC_INGRESS_PORT}
    type: HTTP
    requestPath: ${HC_INGRESS_PATH}
  iap:
    enabled: true
    oauthclientCredentials:
      secretName: my-secret
EOF
    echo
    echo "$ kubectl annotate -n $APPLICATION_NAMESPACE service/frontend --overwrite cloud.google.com/backend-config='{\"default\": \"http-hc-config\"}' cloud.google.com/neg='{\"ingress\":false}' # to annotate the ingress service with BackendConfig" | pv -qL 100
    kubectl annotate -n $APPLICATION_NAMESPACE service/frontend --overwrite cloud.google.com/backend-config='{"default": "http-hc-config"}' cloud.google.com/neg='{"ingress":false}'
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${APPLICATION_NAME}-ingress
  annotations:
    kubernetes.io/ingress.global-static-ip-name: ${APPLICATION_NAME}-iap-global-ip
    networking.gke.io/managed-certificates: ${APPLICATION_NAME}-managedcert
  labels:
    app: ${APPLICATION_NAME}-app
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 80
EOF" | pv -qL 100
kubectl -n $APPLICATION_NAMESPACE apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${APPLICATION_NAME}-ingress
  annotations:
    kubernetes.io/ingress.global-static-ip-name: ${APPLICATION_NAME}-iap-global-ip
    networking.gke.io/managed-certificates: ${APPLICATION_NAME}-managedcert
  labels:
    app: ${APPLICATION_NAME}-app
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 80
EOF
    echo
    echo "$ gcloud --project $GCP_PROJECT projects add-iam-policy-binding $GCP_PROJECT --member=user:\$(gcloud config get-value core/account) --role=roles/iap.httpsResourceAccessor # to grant Cloud IAP/IAP-Secured Web App User role" | pv -qL 40
    gcloud --project $GCP_PROJECT projects add-iam-policy-binding $GCP_PROJECT --member=user:$(gcloud config get-value core/account) --role=roles/iap.httpsResourceAccessor
    echo
    echo "***          WAIT FOR INGRESS TO BE PROVISIONED BEFORE CONTINUING          ***" | pv -qL 100
    echo "*** Note: It can take 10-20 minutes for the load balancer to be functional ***" | pv -qL 100
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},11x"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_ZONE}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE > /dev/null 2>&1 
    echo
    echo "$ gcloud --project $GCP_PROJECT projects remove-iam-policy-binding $GCP_PROJECT --member=user:\$(gcloud config get-value core/account) --role=roles/iap.httpsResourceAccessor # to remove Cloud IAP/IAP-Secured Web App User role" | pv -qL 40
    gcloud --project $GCP_PROJECT projects remove-iam-policy-binding $GCP_PROJECT --member=user:$(gcloud config get-value core/account) --role=roles/iap.httpsResourceAccessor
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE delete Ingress ${APPLICATION_NAME}-ingress # to delete Ingress" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE delete Ingress ${APPLICATION_NAME}-ingress
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE delete BackendConfig http-hc-config # to delete backend config" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE delete BackendConfig http-hc-config
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE delete ManagedCertificate ${APPLICATION_NAME}-managedcert # to delete ManagedCertificate" | pv -qL 40
    kubectl -n $APPLICATION_NAMESPACE delete ManagedCertificate ${APPLICATION_NAME}-managedcert
    echo
    echo "$ kubectl delete secret -n $APPLICATION_NAMESPACE my-secret # to delete secret" | pv -qL 100
    kubectl delete secret -n $APPLICATION_NAMESPACE my-secret
    export BRAND_NAME=$(gcloud --project $GCP_PROJECT alpha iap oauth-brands list --format="value(name)") > /dev/null 2>&1
    export CLIENT=$(gcloud alpha iap oauth-clients list $BRAND_NAME | grep "name: "| awk '{print $2}')
    echo
    echo "$ gcloud --project $GCP_PROJECT alpha iap oauth-clients delete $CLIENT --brand=$BRAND_NAME # to delete OAuth client" | pv -qL 100
    gcloud --project $GCP_PROJECT alpha iap oauth-clients delete $CLIENT --brand=$BRAND_NAME 
else
    export STEP="${STEP},11i"
    echo
    echo "1. Create Brand" | pv -qL 100
    echo "2. Create OAuth client" | pv -qL 100
    echo "3. Create Secret" | pv -qL 100
    echo "4. Configure ManagedCertificate" | pv -qL 100
    echo "5. Configure BackendConfig" | pv -qL 100
    echo "6. Annotate the Ingress service with BackendConfig" | pv -qL 100
    echo "7. Configure Ingress" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"R")
echo
echo "
  __                      __                              __                               
 /|            /         /              / /              /                 | /             
( |  ___  ___ (___      (___  ___        (___           (___  ___  ___  ___|(___  ___      
  | |___)|    |   )     |    |   )|   )| |    \   )         )|   )|   )|   )|   )|   )(_/_ 
  | |__  |__  |  /      |__  |__/||__/ | |__   \_/       __/ |__/||  / |__/ |__/ |__/  / / 
                                 |              /                                          
"
echo "
We are a group of information technology professionals committed to driving cloud 
adoption. We create cloud skills development assets during our client consulting 
engagements, and use these assets to build cloud skills independently or in partnership 
with training organizations.
 
You can access more resources from our iOS and Android mobile applications.

iOS App: https://apps.apple.com/us/app/tech-equity/id1627029775
Android App: https://play.google.com/store/apps/details?id=com.techequity.app

Email:support@techequity.cloud 
Web: https://techequity.cloud

Ⓒ Tech Equity 2022" | pv -qL 100
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"G")
cloudshell launch-tutorial $SCRIPTPATH/.tutorial.md
;;

"Q")
echo
exit
;;
"q")
echo
exit
;;
* )
echo
echo "Option not available"
;;
esac
sleep 1
done
