# compose-service

A linux bootstrap service toolkit for docker-compose. Currently entirely in bash.

Manage docker-compose deployments as system  services using `init` (via `init.d`) , upstart (future), or alternatively as a cron @restart task

## Security Note

This is software that is written for fun, research, and limited use in isolated, physically secure network environments.

In the most invasive case, this utility can install a number of init.d scripts, moreover these scripts will execute `docker-compose` on bootup to bring up your dockerized service.

The script does not request privilege escalation, but instead checks for read/write access to required directories before acting, with no silent sudo's.

However, there is still the possibility of a bug or other issue that causes system corruption.

Use at your own risk, and never in production.


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

## Deployments


compose-service can deploy a docker-compose service to the following system managers

**init.d**

Deploy your docker-compose service and create an init.d startup script

Your service will start,stop, and be managed as a bona-fide init service and can be controlled via the

`service` interface on debian style systems (or various rc systems on others)

**compose-service**

Deploy under a "master" service managed by compose-service, either init or upstart.

Note: this deployment mode couples all the services under the umbrella service, which can extend boot time and cause unexpected issues if one service fails but doesn
compose-service deploys yml and configuration files from your project, additionally it can create init.d, upstart, and crontab jobs to enable docker-compose deployments to be managed by the underlying Linux operating system

Your service will start, stop, and be managed with other services under a `compose-service` master service

**cron**

Deploy the service as an `@reboot` crontab, this allows individual users to manage service with a local compose-service installation

**upstart (FUTURE)**

Deploy your docker-compose service as a bona fide upstart job


## Project Preparation

compose-service can be used on an existing project without any additional configuration by generating a default service name, however due to the limitations and requirements of a boot strap service and for deployment convenience you should add 1 or 2 additional configuration files to your deployment project. 

compose-service expects a docker-compose yml file and a service configuration file in your project root

- `docker-service.yml` (optional) docker compose file tailored for service deployment
- `compose-service` compose-service bash based configuration

in a minimal example only a `compose-service` file needs to be written, in there you can either specify the yml you would like to use or define a yml generator function to allow for bash based deployment tuning.

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

- `SERVICE_NAME` - name for the service (will be the init.d, compose-service or upstart name for this service)
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
-t|--target-dir /var/opt/deploy  root folder for deployment install
-d|--data-dir /var/opt/  root folder for data volumes
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




## Configuration

