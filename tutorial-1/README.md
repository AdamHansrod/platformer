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

For the Repository and Load Balancer components we going to use a docker [nginx](https://docs.docker.com/samples/library/nginx/) image then extended with different configs


First lets create our first actual Docker image, based off the canonical nginx image, that will serve as our load balancer for the platform

```
$> cd loadbalancer
$> docker build --tag platformer/loadbalancer:latest .
```

Now lets create our repository service image. For our purposes, this service is going to serve the app and config artefacts for our hello-world app. In a real-world scenario the artefacts/config functionality might not be needed at all, or could be a proxy to an production grade artefact/config solutions such as artifactory/s3 or vault

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

Now we’ve got the images, lets boot up using our earlier bootstrap sequence
```
# Start DNS 
$> docker run -d --name dns -e DNS_DOMAIN=platform -p 53:53/udp  -v /var/run/docker.sock:/var/run/docker.sock ruudud/devdns
# Start Repository
$> docker run -v repository/nginx:/usr/share/nginx/html:ro -p 80:80 --dns=`docker inspect -f "{{ .NetworkSettings.IPAddress }}" dns` -d platformer/repository

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

An example of a zero downtime deployment of the hello-world app would be:

* Instead prepend the version of the component/config to the docker names for the containers, for example the hello-world app would start with a docker name of 'hello-world-<version>'

* Start the new version of the hello-world app, with the new docker name of 'hello-world-<version-2>'

* Change the Load Balancer config and reload 
    ```
    $> docker exec -it loadbalancer /bin/bash
    # Add the new upstream server
    loadbalancer> vim /etc/nginx/conf
    loadbalancer> service nginx reload
    ```
 

Now we have our own little pseudo-platform that allows us to deploy any number of app’s in docker containers, but there’s still a lot of work that we could easily automate to reduce our need on manual editing. 
