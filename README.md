# compose-service

A linux service toolkit for docker-compose. Currently entirely in bash.

Manage docker-compose as services using `init` (via `init.d`) or alternatively as a cron @restart task

## Security Note

This is software that is written for fun, research, and limited use in isolated, physically secure network environments.

In the most invasive case, this utility can install a number of init.d scripts, moreover these scripts will execute `docker-compose` on bootup to bring up your dockerized service.

The script does not request privilege escalation, but instead checks for read/write access to required directories, with no silent sudo's.

However, there is still the possibility of a bug or other issue that causes system corruption.


## Installation

This is a simple single script utility.

By default install.sh creates the following default directories and targets

 - **compose-service** `/usr/local/bin/compose-service`
 - **Configuration Dir** `/etc/compose-service
 - **Service Deployment Dir** `/var/opt/compose-service/deploy
 - **Service Data Dir** `/var/opt/compose-service/data


## Project Preparation




## Invocation 




