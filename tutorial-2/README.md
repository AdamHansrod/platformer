# platformer - Creating a scalable app platform

## Tutorial #2 Orchestrating our platform containers via kubernetes (locally)

### Prerequisites
*[Docker installed](https://www.docker.com/)

*[Kubernetes installed](https://kubernetes.io/)

*[Minikube installed](https://kubernetes.io/docs/getting-started-guides/minikube/#installation)

*[Minikube Dnsmasq wrapper installed](https://github.com/superbrothers/minikube-ingress-dns )

### Kubernetes Platform Architecture
We now have a choice whether we’re going to continue the use of our platform DNS component and load balancing components and run them as ‘headless’ services in kubernetes terminology, or use the in-built kubernetes kube-dns and Ingress services to manage this functionality within the platform.

For the purpose of using and learning more kubernetes features, we’re going to use the kube-dns and Ingress features of Kubernetes, leaving us just with the App and the Repository components.

We’re going to encapsulate our App and Repository images into their own Pods, which will allow us to govern how those containers will run.

To manage our Pods, we’ll use the Deployment resource, which will internally manages a Replica Sets that ensures there are enough Pods to satisfy according to the configuration.

To enable interaction with the Pods (which are inherently disposable), we’ll expose a consistent way to access them by using a Kubernetes a Service. 

The bootstrap process is:
* Start local docker repository

* Start minikube cluster

* Start kubernetes dashboard (optional)

* Start Repository Component

* Start Hello World App

### Setting up our local machine’s cluster
#### Start local docker registry
We’ll need to setup a local docker registry to allow the kubernetes cluster to pull images from. 

Start a local docker registry
```
$> docker run -d -p 5000:5000 --restart=always --name myregistry registry:2
```
Push your local images
```
$> docker tag platformer/app-base localhost:5000/platformer/app-base
$> docker tag platformer/repository localhost:5000/platformer/repository
$> docker push localhost:5000/platformer/app-base
$> docker push localhost:5000/platformer/repository
```

#### Start local DNS server
We’ll need to setup a way for use to resolve hostnames against our local cluster. We could manually set this up using /etc/hosts or similar techniques depending on your OS, but to simplify the instructions for this tutorial, we’re going to use the below dnsmasq wrapper. Minikube is looking at bringing this functionality to users by default by providing an addon, however this still isn’t in a stable release.
https://github.com/superbrothers/minikube-ingress-dns 

#### Start our local cluster
Now we have a way to resolve a DNS entry against our local cluster, and somewhere for our cluster to pull docker images from, let’s start the local cluster using our local registry and check you can pull your local images inside the cluster.
 
This tutorial also assumes that the you’re running docker on mac, and the docker vm has the ifconfig for vboxnet0 on your local machine has the ip of 192.168.99.1. Other OS’s will need to adapt the below instructions as needed.

Note that if you’ve already got a minikube up and running you must delete the cluster and start again to ensure: 

* That you’ll be able to pull your local docker images, as you’ll see http responses from the local docker registry rather than the https that minikube is expecting.

* That you’ll be able to route a hostname to your minikube cluster
```
$> minikube start --insecure-registry=192.168.99.1:5000
$> minikube ssh
minikube> docker pull 192.168.99.1:5000/platformer/app-base
minikube> Status: Downloaded newer image for 192.168.99.1:5000/platformer/app-base:latest
```

#### Enable the kubernetes dashboard
Let’s also enable the kubernetes dashboard locally
```
$>minikube addons enable dashboard
```
This will then spin up kubernetes-dashboard under the ‘kube-system’ namespace, which can be accessed by running the proxy command for kubectl
```
$>minikube dashboard
```
Which should open 
[http://192.168.99.100:30000/#!/overview?namespace=default]([http://192.168.99.100:30000/#!/overview?namespace=default]) 

#### Running our Kubernetes Services and Deployments
Now we have our configuration, let’s deploy our services(App, Repository) via kubernetes as their own services and deployments.

First, lets start up the repository service, we’ll need to share our local folders/files to minikube, to allow the pods to be able to then see them. Unfortunately we’ll need to use two terminals as `minikube mount` will need a terminal active to be able to work.
```
$t1> minikube mount repository/nginx:/usr/share/nginx/html
$t2> kubectl apply -f k8s/component/repository/
```
And then our hello-world app
```
$t2> kubectl apply -f k8s/component/app/
```
And finally our ingress
```
$t2> kubectl apply -f k8s/component/ingress.yaml
```
Now we can test if the hello-world app is working
```
$t2> curl http://hello-world.minikube.dev/greeting
```


