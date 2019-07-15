#!/usr/bin/bash

# Script to deploy the app in production.

NAMESPACES=$1

if [ "$1" == "" ]; then

  echo "please mention a namespace."
  echo "Like below: - "
  echo "bash Auto_deploy.sh production"
  echo "or"
  echo "bash Auto_deploy.sh staging"

else
  echo "Deploying into ${NAMESPACES}"
  kubectl apply -f namespaces/${NAMESPACES}-ns.yml

  echo "Checking if namesapaces is created."
  kubectl get ns | grep ${NAMESPACES}

  echo "Setting ${NAMESPACES} to Default."
  kubectl config set-context ${NAMESPACES} --namespace=${NAMESPACES} --user=minikube --cluster=minikube
  kubectl config use-context ${NAMESPACES}

  echo "Enamble minikube built in ingres-controller."

  minikube addons enable ingress

  echo "Check if ingress controller is enable. "
  kubectl get pods -A | grep nginx-ingress-controller

  echo "Check which context is set to default."
  kubectl config get-contexts | grep "^*"

  echo "Deploy our Guestbook app."

  kubectl apply -f ingress/guestbook-ingress.yaml

  echo "Depoying frontend."
  kubectl apply -f guestbook/frontend.yaml

  echo "Deploying redis master and slave."
  kubectl apply -f guestbook/redis-master.yaml
  kubectl apply -f guestbook/redis-slave.yaml

  echo "Check if all services is up and running."
  kubectl get services | grep "frontend\|redis"

  echo "Get service url"
  URL=$(minikube service list | grep frontend | awk '{print $6}')

  echo "Testing the URL"
  curl -IL ${URL}

  echo "setting the scale to 1 "
  kubectl scale --replicas=1 -f guestbook/frontend.yaml

  echo "Creating autoscale for the frontend deployment."
  kubectl autoscale deployment frontend --min=1 --max=10 --cpu-percent=10

  echo "Check how many pods are running."
  kubectl get pods | awk '{print $1,"\t\t\t\t", $2}'

  echo "Running a test on the pods to check autoscaling."
  for I in {1..150}; do
    echo "--BEGIN--"
    curl -il ${URL}
    echo "<<<< END >>>>" kubectl get pods | grep frontend | awk '{print $1,"\t\t\t\t", $2}'
  done

  echo "Check the events below."
  kubectl describe deployment frontend | grep "Events:" -A 20

  echo "PRINT URL."
  echo ${URL}

  echo "END"

fi
