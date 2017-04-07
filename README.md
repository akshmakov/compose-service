# compose-service

A linux bootstrap service toolkit for docker-compose. Currently entirely in bash.

Manage docker-compose deployments as system  services using `systemd` (via `init.d`) , upstart (FUTURE), or alternatively as a cron @restart task

## Security Note

This is software that is written for fun, research, and limited use in isolated, physically secure network environments.

In the most invasive case, this utility can install a number of system scripts, moreover these scripts will execute `docker-compose` on bootup to bring up your dockerized service.

The script does not request privilege escalation, but instead checks for read/write access to required directories before acting and quits if unavailable, with no silent sudo's.

However, there is still the possibility of a bug or other issue that causes system corruption.

Use at your own risk, and never in production before a 1.0 release.


## Sample Use (Raspbian `nginx-docker` Boot time service)

Deploying an nginx server on a raspbian os, assuming `compose-service` has been installed to default location

First, for reference - our sample project is two files

```docker-service.yml

version: '2'

services:
  web:
    image: armhfbuild/nginx:latest
    ports:
      - "8080:80"
```


```compose-service
SERVICE_NAME="nginx-test"
```

A service needs to be deployed, i.e loaded into the `compose-service` configuration and the environment prepared

```
$# compose-service deploy
Command: deploy
Found + Loading Service Definition : ./compose-service
Deploying compose-service nginx-test
Checking and Preparing Deployment Directories for nginx-test
Preparing compose-service configuration for nginx-test
```

Afterwards a service can be installed to a system manager, e.g. systemd 

```
$# compose-service install-initd
Command: install-initd
Found + Loading Service Definition : ./compose-service
Installing compose-service nginx-test as init.d service under system root
Preparing initd service for nginx-test service install : /etc/init.d/nginx-test
Updating init.d rc scripts using update-rc.d
Done Install initd service for nginx-test
```

Now your service can be started

```
$# service nginx-test start
$# service nginx-test status
● nginx-test.service - LSB: compose-service for nginx-test
   Loaded: loaded (/etc/init.d/nginx-test)
      Active: active (exited) since Sat 1972-01-01 00:00:05 PDT; 2s ago
        Process: 31337 ExecStart=/etc/init.d/nginx-test start (code=exited, status=0/SUCCESS)
Jan 01 00:00:00 raspbian nginx-test[31337]: Starting compose-service: nginx-testCreating network "nginxtest_default" with the default driver
Jan 01 00:00:01 raspbian nginx-test[31337]: Creating nginxtest_web_1
Jan 01 00:00:05 raspbian systemd[1]: Started LSB: compose-service for nginx-test.
```

Check in docker

```
$# docker ps
CONTAINER ID        IMAGE                     COMMAND                  CREATED             STATUS              PORTS                                        NAMES
a6d468db0b82        armhfbuild/nginx:latest   "nginx -g 'daemon ..."   3 minutes ago       Up 3 minutes        443/tcp, 0.0.0.0:8080->80/tcp                nginxtest_web_1
```


Now we check the html server is running

```
$# curl 127.0.0.1:8080
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...... SNIP CONTENT ...
</html>
```

**Last Step**: Reboot and watch the boot screen to see your service start and print a status message, a bona fide system service, exciting!


## Installation

compose-service  is a  single script utility, everything is contained within [compose-service.sh](compose-service.sh) and it can be used standalone or packaged with your application.

To use as a system tool you may choose to install the utlity to your system. For this an install script [install.sh](install.sh) is provided

By default install.sh creates the following default directories and targets

 - **compose-service** `/usr/local/bin/compose-service` utility installation
 - **Configuration Dir** `/etc/compose-service` `compose-service` configuration files
 - **Service Deployment Dir** `/var/opt/compose-service/deploy` location of docker-compose yml files
 - **Service Data Dir** `/var/opt/compose-service/data` location where local volumes are mounted for service

You may configure install.sh directories with the following environment variables when calling `install.sh`


`$COMPOSE_SERVICE_BIN`

Default: `/usr/local/bin/compose-service`

`$COMPOSE_SERVICE_TARGET_DIR`

Default: `/var/opt/compose-service/deploy/`

`$COMPOSE_SERVICE_CONFIG_DIR`

Default: `/etc/compose-service/`

`COMPOSE_SERVICE_DATA_DIR`

Default: `/var/opt/compose-service/`

Indicate intent to delete

`SERVICE_DELETE=YES`


e.g. to install the application in `/usr/bin/` and store the data root under `/mnt/services/`


`COMPOSE_SERVICE_BIN=/usr/bin/compose-service COMPOSE_SERVICE_DATA_DIR=/mnt/services ./install.sh`

## Deployments


compose-service can deploy a docker-compose service to the following system managers

**init.d**

Deploy your docker-compose service and create systemd  startup script in `/etc/init.d`

Your service will start,stop, and be managed as a bona-fide service and can be controlled via the `service` interface on certain debian style systems.

**compose-service**

Deploy under a "master" service managed by compose-service, either init or upstart.

Note: this deployment mode couples all the services under the umbrella service, which can extend boot time and cause unexpected issues if one service fails. 

Your service will start, stop, and be managed with other services under a `compose-service` master service

**cron**

Deploy the service as an `@reboot` crontab, this allows individual users to manage service with a local compose-service installation

**upstart (FUTURE)**

Deploy your docker-compose service as a bona fide upstart job

**other**

Hope to support more script based service systems in the future.

## Project Preparation

compose-service can be used on an existing project without any additional configuration by generating a default service name, however due to the limitations and requirements of a boot strap service and for deployment convenience you should add 1 or 2 additional configuration files to your deployment project. 

compose-service expects a docker-compose yml file and a service configuration file in your project root

- `docker-service.yml` (optional) docker compose file tailored for service deployment
- `compose-service` compose-service bash based configuration

in a minimal example only a `compose-service` file needs to be written, in there you can either specify the yml you would like to use or define a yml generator function to allow for bash based deployment tuning.

So Basically,  there are 4 ways to structure the configuration for your deployment project from least invasive to most

1. Create nothing, rely on `docker-compose.yml`
   - `docker-compose.yml` is the final fallback for the utility
   - service name autogenerated from date-time
   - override name with environment variable `SERVICE_NAME=name-to-deploy compose-service ...`
   - Best for simplest projects or experimentation
2. Create service specific docker-compose file, `docker-service.yml`
   - `docker-service.yml` is the default yml used (if found)
   - service name is is still autogenerated (override needed)
3. Create service specific configuration, `compose-service`
   - `compose-service` if found will be used
   - should contain `$SERVICE_NAME`
       to define the service name (used to refer to deployment in compose-service and init etc.)
   - should as well have `$SERVICE_DEPLOY_YML`
       to indicate name of YML to deploy (default: `docker-service.yml`)
   - Alternatively, can contain `$SERVICE_INIT_FN` a no-args bash function
       to bashfully generate YML and print it to  stdout for compose-service to use
4. 2 + 3
   - Maximum control/customization
   


### docker-service.yml

Since a service typically should start (or background) quickly during boot the compose file should be stripped
to barebones, specifically, compose-service does a  no-build, no-pull docker-compose invocation (only pull if a tag doesn't exist locally).

A typical service deployment pipeline could look like

1. Pull latest service release
2. docker build/pull to update local image store
3. update compose-service
4. restart system service to spin up new image/configuration

The `docker-service.yml` should then ideally refer to a fixed image tag with no build directives. Volumes can be created on the host relative to working dir and will be  managed by compose-service under the `SERVICE_DATA_DIR`, additional docker volumes or static host mounts will not be managed by compose-service.

**Example**: [docker-service.yml](examples/docker-service.yml)


### compose-service

The compose-service file is fundamentally an include file with shell variables to direct the compose-service utility.

At a minimum the compose-service file should define the following variables

- `SERVICE_NAME` - name for the service (will be the systemd, compose-service or upstart name for this service)
- `SERVICE_DEPLOY_YML` - path to the deployment YML (will be copied)
- (Optional) `SERVICE_INIT_FN` - a no parameter bash function which prints the YML to stdout to be printed to deployment file

**Example**: [compose-service](examples/compose-service)

## Invocation 


Usage info is reproduced below


```
Usage: compose-service [OPTIONS] action
  OPTIONS:
	-s|--service ./compose-service service definition file
	-f|--force secondary flag required to destroy system
	-v|--verbose verbose (extra messages)
	-c|--config /etc/compose-service/
	-t|--target-dir /var/opt/compose-service/deploy  root folder for deployment install
	-d|--data-dir /var/opt/compose-service/data  root folder for data volumes
	-r|--dry-run dry-run print steps but do not install service
	-h|--help Print This Help
  action:
	deploy - deploy compose-service (does not install init.d or cron)
	install-initd - install as init.d service
	remove-initd - remove int.d service
	install-cron - install service as crontab under current user
	install-compose - install under compose-service umbrella
	remove-compose - remove from compose-service umbrella
	update - update deployment
	remove - remove deployment and service
	destroy - remove and delete data (requires -f|--force)

```


OPTIONS are used to specify the operating environment. If you would like to examine the actions that `compose-service` will do to your system, executing with `-r -v` or `--dry-run --verbose` options will give print the full content of the confuguration and docker-compose yml file generated, as well as any system calls or file system changes. The other options are used to point to alternative locations for configuration, data, and deployment directories


## Configuration

