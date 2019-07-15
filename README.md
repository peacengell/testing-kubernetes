## LEVEL1 Tasks.

## Automated deployment.

    git clone git@github.com:peacengell/testing-kubernetes.git

    cd testing-kubernetes

    bash Auto_deploy.sh production [To deploy in production namespaces.]
    bash Auto_deploy.sh staging [To deploy in staging namespaces.]


## Steps using to create the cluster using minikube on localhost.


1. Get minikube version.
```
minikube version 
minikube version: v1.2.0
```
2. Start the cluster.
```
minikube start
```




## 1. Create two Namespace, staging and production 

    ```
    kubectl apply -f namespaces/staging-ns.yml
    ```
    OUTPUT :
    ```
    kubectl get ns
        NAME              STATUS   AGE
        default           Active   16m
        kube-node-lease   Active   16m
        kube-public       Active   16m
        kube-system       Active   16m
        staging           Active   4s

    ```
    ```
    kubectl apply -f namespaces/production-ns.yml 
    ```
    ```
    OUTPUT :
    
    kubectl get ns
        NAME              STATUS   AGE
        default           Active   21m
        kube-node-lease   Active   21m
        kube-public       Active   21m
        kube-system       Active   21m
        production        Active   1s
        staging           Active   5m24s
    ```

## Using the default nginx-ingress controller.
    ```
    minikube addons enable ingress

    ```

## Get all pods from all namespaces.
    ```
    kubectl get pods -A
        NAMESPACE     NAME                                        READY   STATUS    RESTARTS   AGE
        kube-system   coredns-5c98db65d4-9hj8b                    1/1     Running   1          88m
        kube-system   coredns-5c98db65d4-lz52s                    1/1     Running   1          88m
        kube-system   default-http-backend-59f7ff8999-sqfrm       1/1     Running   0          17m
        kube-system   etcd-minikube                               1/1     Running   0          87m
        kube-system   kube-addon-manager-minikube                 1/1     Running   0          87m
        kube-system   kube-apiserver-minikube                     1/1     Running   0          87m
        kube-system   kube-controller-manager-minikube            1/1     Running   0          87m
        kube-system   kube-proxy-5d4sq                            1/1     Running   0          88m
        kube-system   kube-scheduler-minikube                     1/1     Running   0          87m
        kube-system   nginx-ingress-controller-7b465d9cf8-nrtlr   1/1     Running   0          17m
        kube-system   storage-provisioner                         1/1     Running   0          88m
    ```



## FROM now on we can use staging namespace to deploye our app.

     -  create and Set default namespaces
            ```
            kubectl config set-context staging --namespace=staging --user=minikube --cluster=minikube
            kubectl config use-context staging
            ```

    ```
    kubectl config get-contexts
        CURRENT   NAME         CLUSTER    AUTHINFO   NAMESPACE
                  minikube     minikube   minikube   
                  production   minikube   minikube   production
        *         staging      minikube   minikube   staging

    ```

### 3.1 Create a Deployment

```
    kubectl apply -f ingress/guestbook-ingress.yaml 
        ingress.networking.k8s.io/guestbook created
```
```
    kubectl apply -f  guestbook/frontend.yaml 
        deployment.apps/frontend created
        service/frontend created
```
```
    kubectl apply -f  guestbook/redis-master.yaml 
        deployment.apps/redis-master created
        service/redis-master created
```
```
    kubectl get services
        NAME           TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
        frontend       NodePort    10.106.169.181   <none>        80:30563/TCP   31s
        redis-master   ClusterIP   10.100.233.159   <none>        6379/TCP       21s

```

## Get the URL and access the url via curl

```
minikube service list
|-------------|----------------------|-----------------------------|
|  NAMESPACE  |         NAME         |             URL             |
|-------------|----------------------|-----------------------------|
| default     | kubernetes           | No node port                |
| kube-system | default-http-backend | http://192.168.99.100:30001 |
| kube-system | kube-dns             | No node port                |
| staging     | frontend             | http://192.168.99.100:30563 |
| staging     | redis-master         | No node port                |
|-------------|----------------------|-----------------------------|

```
```
curl -il http://192.168.99.100:30563
HTTP/1.1 200 OK
Date: Mon, 15 Jul 2019 08:20:30 GMT
Server: Apache/2.4.10 (Debian) PHP/5.6.20
Last-Modified: Wed, 09 Sep 2015 18:35:04 GMT
ETag: "399-51f54bdb4a600"
Accept-Ranges: bytes
Content-Length: 921
Vary: Accept-Encoding
Content-Type: text/html

<html ng-app="redis">
  <head>
    <title>Guestbook</title>
    <link rel="stylesheet" href="//netdna.bootstrapcdn.com/bootstrap/3.1.1/css/bootstrap.min.css">
    <script src="https://ajax.googleapis.com/ajax/libs/angularjs/1.2.12/angular.min.js"></script>
    <script src="controllers.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/angular-ui-bootstrap/0.13.0/ui-bootstrap-tpls.js"></script>
  </head>
  <body ng-controller="RedisCtrl">
    <div style="width: 50%; margin-left: 20px">
      <h2>Guestbook</h2>
    <form>
    <fieldset>
    <input ng-model="msg" placeholder="Messages" class="form-control" type="text" name="input"><br>
    <button type="button" class="btn btn-primary" ng-click="controller.onRedis()">Submit</button>
    </fieldset>
    </form>
    <div>
      <div ng-repeat="msg in messages track by $index">
        {{msg}}
      </div>
    </div>
    </div>
  </body>
</html>
```

## Seting replicas to one.
```
kubectl scale --replicas=1 -f guestbook/frontend.yaml
```

## Make frontend autoscale.
    ```
    kubectl autoscale deployment frontend --min=1 --max=10 --cpu-percent=10
    ```
## Check how many pods running. 

```
kubectl get pods
    NAME                            READY   STATUS    RESTARTS   AGE
    frontend-678d98b8f7-6gzdk       1/1     Running   0          77m
    redis-master-545d695785-5cpsg   1/1     Running   0          77m

```

## Test the Autoscaling policy.

-- Quick and dirty.

for I in {1..150} ;do  echo "--BEGIN--";curl -I http://192.168.99.100:30563; echo "<<<< END >>>>" kubectl get pods; done

## Check the events.

```
kubectl describe deployment frontend
```
        Events:
        Type    Reason             Age                From                   Message
        ----    ------             ----               ----                   -------
        Normal  ScalingReplicaSet  28m (x2 over 95m)  deployment-controller  Scaled up replica set frontend-678d98b8f7 to 3
        Normal  ScalingReplicaSet  21m (x3 over 26m)  deployment-controller  Scaled up replica set frontend-678d98b8f7 to 2
        Normal  ScalingReplicaSet  18m (x5 over 29m)  deployment-controller  Scaled down replica set frontend-678d98b8f7 to 1