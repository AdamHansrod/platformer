# platformer - Creating a scalable app platform

## Tutorial #1 Designing & Creating our first platform
### Docker Platform Architecture
We’re going have a few components:
* A DNS service so we can know where to send all the requests we have to our Load Balancer

* A Load Balancer, which will use Nginx to load balance traffic for the rest of our platform components.
    
    The load balancer, will allow us to pick our update strategy later (either blue-green deployments or rolling updates) by the way we change the nginx config files, as well as being able to horizontally scale against requests to our hosted apps or our repository component

* A Repository, that will host all our config and app artefacts

* Our app image, which on boot will run startup.sh that will bootstrap our webapps, were going to provide an app name to as a parameter, which startup.sh will use to:

    * Download the app from the repository service

    * Request the latest config including the startup command for the app from from repository component and export the config into an environment variables

    * Start an app up via the config startup command

    The app image to enables us to provide a generic container and common dependencies to each app we want to host on our platform.


The bootstrap process is:

* Start DNS

* Start Repository Service

* Start Load balancer

* Start Hello World App Service


### Creating our docker images and our basic platform
Our docker images that will serve as a base for our config service and our main app

#### Prerequisites
*[Docker installed](https://www.docker.com/)

#### Creating the images
Now we’ve got an architecture to base our work on, let’s start building our docker images.

For the DNS service, we’re going to use [devdns](https://github.com/ruudud/devdns), which will allow us to use hostnames within the platform, rather than hardcoding IP addresses.

For the Repository and Load Balancer components we're going to use a docker [nginx](https://docs.docker.com/samples/library/nginx/) image, extended with different configs.


First let's create our first actual Docker image, based off the canonical nginx image, that will serve as our load balancer for the platform

```
$> cd loadbalancer
$> docker build --tag platformer/loadbalancer:latest .
```

Now let's create our repository service image. For our purposes, this service is going to serve the app and config artefacts for our hello-world app. In a real-world scenario the artefacts/config functionality might not be needed at all, or could be a proxy to an production grade artefact/config solutions such as artifactory/s3 or vault

```
$> cd repository
$> docker build --tag platformer/repository:latest .
```

Now we have our first two images, let’s build our base app image

```
$> cd app-base
$> docker build --tag platformer/app-base:latest .
```

### Starting up our platform

Now we’ve got the images, let's boot up using our earlier bootstrap sequence
```
# Start DNS 
$> docker run -d --name dns -e DNS_DOMAIN=platform -p 53:53/udp  -v /var/run/docker.sock:/var/run/docker.sock ruudud/devdns
# Start Repository
$> docker run -v repository/nginx:/usr/share/nginx/html:ro -p 80:80 --dns=`docker inspect -f "{{ .NetworkSettings.IPAddress }}" dns` -d platformer/repository
^ above step gave me error:
```
mattlap:~/github/platformer/tutorial-1 mralph$ docker run -v repository/nginx:/usr/share/nginx/html:ro -p 80:80 --dns=`docker inspect -f "{{ .NetworkSettings.IPAddress }}" dns` -d platformer/repository

docker: Error response from daemon: create repository/nginx: "repository/nginx" includes invalid characters for a local volume name, only "[a-zA-Z0-9][a-zA-Z0-9_.-]" are allowed. If you intended to pass a host directory, use absolute path.
```

#Test the repository service is sharing the locally mounted files
$> curl localhost:80/config/hello-world/hello-world.config
STARTUP_COMMAND="./gradlew bootRun"

# Start Load balancer
$> docker run --name loadbalancer -p 8080:80 --dns=`docker inspect -f "{{ .NetworkSettings.IPAddress }}" dns` -d platformer/loadbalancer

# Start Hello-World App
$> docker run -P --name hello-world --dns=`docker inspect -f "{{ .NetworkSettings.IPAddress }}" dns` -d platformer/app-base hello-world repository.platform
```

Hopefully, that should have come up all working and fine, and we now have our own 
platform on our local machine!
```
$> curl -v localhost:80/greeting
```

#### Deploying new applications and further work
Now if we need to add a new app to our pseudo-platform we can:
* Add the configs and artefacts to the repository service

* Start the new app up via our dynamic app image container

* Add the nginx config to the load balancer

* Reload the load balancer

If we wanted a zero downtime deployment of the hello-world app we could:

* Instead prepend the version of the component/config to the docker names for the containers, for example the hello-world app would start with a docker name of 'hello-world-<version>'

* Start the new version of the hello-world app, with the new docker name of 'hello-world-<version-2>'

* Change the Load Balancer config and reload 
    ```
    $> docker exec -it loadbalancer /bin/bash
    # Add the new upstream server
    loadbalancer> vim /etc/nginx/conf
    loadbalancer> service nginx reload
    ```

* 

Now we have our own little pseudo-platform that allows us to deploy any number of app’s in docker containers, but there’s still a lot of work that we could easily automate to reduce our need on manual editing. 


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

## Tutorial #3 Run our platform on GKE/EKS

## Tutorial #4 Run our platform on AWS with KOPS

## ????
## Profit
