#!/bin/bash
#Common Things
### Usage
### Command Line options
### compose-service install
###
### Environment Variables
### COMPOSE_SERVICE_TARGET_DIR -t --target-dir
###   Default: /var/opt/compose-service/deploy/
### COMPOSE_SERVICE_CONFIG_DIR -c --config-dir
###   Default: /etc/compose-service/
### COMPOSE_SERVICE_DATA_DIR -d --data-dir
###   Default: /var/opt/compose-service/$SERVICE_NAME/
### COMPOSE_SERVICE_DEFINITION -s --service
###   Location of service definition file
###   Default: ./compose-service
###   







#########################################################
###       Boiler Plate Stuff ############################
#########################################################

## Service Global Variables ##
PROGNAME=$(basename $0)
INVOKE_TS=$(date +"%s")


COMMAND_LIST="install install-service install-cron update remove destroy deploy"



function error_exit
{
    #----------------------------------------------------------------
    #Function for exit due to fatal program error
    #Accepts 1 argument:
    #string containing descriptive error message
    #----------------------------------------------------------------
    echo "${PROGNAME}: ${1:-"Unknown Error"}" 1>&2
    exit 1
}



function usage
{
    #--------------------------------------
    # print the usage doc
    #--------------------------------------
    cat <<-EOF
Usage: $PROGNAME [OPTIONS] action
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
    install-cron - install service as crontab under current user
    install-compose - install under compose-service umbrella
    update - update deployment
    remove - remove deployment and service
    destroy - remove and delete data (requires -f|--force)
EOF
    exit 0
}

###################################################
######## Service Variables ########################
###################################################

SERVICE_FILE=${COMPOSE_SERVICE_DEFINITION-$(pwd)/compose-service}
SERVICE_NAME="compose-service-$INVOKE_TS"
TARGET_DIR=${COMPOSE_SERVICE_TARGET_DIR-/var/opt/compose-service/deploy}
DATA_DIR=${COMPOSE_SERVICE_DATA_DIR-/var/opt/compose-service}
CONF_DIR=${COMPOSE_SERVICE_CONFIG_DIR-/etc/compose-service}
VERBOSE=0
FORCE=NO
DRY_RUN=NO
COMMAND="HELP"


#####################################################
########## Options Processing #######################
#####################################################


if [[ $# = 0 ]]; then
    usage
fi

while [[ $# -gt 0 ]]
do
    key="$1"

    case $key in
	-s|--service)
	    SERVICE_FILE=$2
	    shift
	    shift
   	    ;;
	-f|--force)
	    FORCE=YES
	    shift
	    ;;
	-t|--target-dir)
	    TARGET_DIR=$2
	    shift
	    shift
	    ;;
	-v|--verbose)
	    VERBOSE=1
	    shift
	    ;;
	-c|--config)
	    CONF_DIR=$2
	    shift
	    shift
	    ;;
	-r|--dry-run)
	    DRY_RUN="YES"
	    shift
	    ;;
	-d|--data-dir)
	    DATA_DIR=$2
	    shift
	    shift
	    ;;
	-h|--help)
	    usage
	    error_exit "Should Not Get Here"
	    ;;	
	-*|--*)
	    # unknown option
	    error_exit "Unknown Option $1"
	    ;;
	*)
	    break
	    ;;
    esac
done

if [[ -n $1 ]]; then
    COMMAND=$1
    echo "Command: $COMMAND"
else
    error_exit "You need to specify a command"
fi


		  
#setup verbose mode
if [ "$VERBOSE" = 1 ]; then
    exec 4>&2 3>&1
else
    exec 4>/dev/null 3>/dev/null
fi


if [[ $DRY_RUN == "NO" &&  $EUID != 0 ]]; then
    error_exit "Please run as root"
fi



## Verbose Mode Option Logging
cat <<-EOF >&3
---------------------debug-------------------------
compose-service configuration pre load
    generic service name: $SERVICE_NAME
                 workdir: $(pwd)
                 command: $COMMAND
      service definition: $SERVICE_FILE
       target deployment: $TARGET_DIR
         deployment data: $DATA_DIR
  compose-service config: $CONF_DIR
            force delete: $FORCE
---------------------------------------------------
EOF

     
     


################################################################
#### Load  Service Specific Environment ########################
################################################################

if [ -e  $SERVICE_FILE ] ; then
    source $SERVICE_FILE
fi

if [ -e $SERVICE_FILE.override ] ; then
    source $SERVICE_FILE.override
fi

if [[ -z $SERVICE_YML \
	    || -z  $SERVICE_INIT_FN \
	    || -z $SERVICE_DESTROY_FN \
	    || -z $SERVICE_TEST \
    ]] ; then

    
    echo "Malformed Service File $SERVICE_FILE : Missing Required Variables"
    
fi

    



SERVICE_DEPLOYMENT=$TARGET_DIR/$SERVICE_NAME.yml
SERVICE_DATA=$DATA_DIR/$SERVICE_NAME




##########################################################
### Deployment Functions ####### #########################
##########################################################
function prep_deployment
{
    return 0
}

function prep_config
{
    return 0
}

function deploy_service
{
    return 0
}

function destroy_service
{
    return 0
}


##########################################
### Peform Command########################
##########################################


case $COMMAND in
    deploy)
	echo "Deploying Service $SERVICE_NAME"
	# do_deploy
	;;
    install-initd)
	echo "Installing init.d service for $SERVICE_NAME"
	# do_install_init
	;;
    install-cron)
	echo "Installing $SERVICE_NAME as crontab under current user $USER"
	# do_install_cron
	;;
    install-compose)
	echo "Installing $SERVICE_NAME under compose-service umbrella"
	# do_install_compose
	;;
    update)
	echo "Updating $SERVICE_NAME"
	# do_update
	;;
    remove)
	echo "Removing $SERVICE_NAME"
	# do_remove
	;;
    destroy)
	echo "Destroying $SERVICE_NAME"
	# do_destroy
	;;
    *)
	error_exit "Unknown Command"
	;;
esac		
