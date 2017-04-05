#!/bin/bash
### compose-service
###  a tool to manage docker-compose deployments as services
###  on linux systems
###
### A service is roughly speaking a "permanent" docker-compose deployment
###
###
### Services can be deployed under:
###  crontab - schedule service start on power on via crontab
###  init.d  - register service as its own init.d script
###  compose-service - register service under the generic compose-service init.d
###  
###
### Environment Variables can override defaults
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

## compose-service utility Global Variables ##
PROGNAME=$(basename $0)
INVOKE_TS=$(date +"%s")


function error_exit
{
    #----------------------------------------------------------------
    # Function for exit due to fatal program error
    # Accepts 1 argument:
    # string containing descriptive error message
    #----------------------------------------------------------------
    echo "${PROGNAME}: ${1:-"Unknown Error"}" 1>&2
    exit 1
}

function run_dry
{
    #-----------------------------------------------------
    # If DRY_RUN != NO in Environment,
    #  simply echo the command
    # Limitation: Does not handle pipes/redirects
    #-----------------------------------------------------
    if [[ $DRY_RUN = NO ]]; then
	${@}
    else
	echo "-dry-run $@"
    fi
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

# Service Specific Variable File (analog to docker-compose.yml)
SERVICE_FILE=${COMPOSE_SERVICE_DEFINITION-$(pwd)/compose-service}

# Default Service Name (typically set by service file)
SERVICE_NAME=${COMPOSE_SERVICE_NAME-"compose-service-$INVOKE_TS"}

# Service YML deployment root dir
TARGET_DIR=${COMPOSE_SERVICE_TARGET_DIR-/var/opt/compose-service/deploy}

# Service YML Data Volume Root
DATA_DIR=${COMPOSE_SERVICE_DATA_DIR-/var/opt/compose-service}

# Configuration Directory
CONF_DIR=${COMPOSE_SERVICE_CONFIG_DIR-/etc/compose-service}

###Application Flags ###
VERBOSE=0
FORCE=NO
DRY_RUN=NO

### Command Placeholder
COMMAND="HELP"


#####################################################
########## Options Processing #######################
#####################################################

## Following Parses the -abc/--do-thing-xyz options
## Most options modify one of the service variables above
## A few set Application Flags
## Command Processing Happens After

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


## All options have "-" or "--"
## First string after options is our command
## Command Arguments can be added later
if [[ -n $1 ]]; then
    COMMAND=$1
    echo "Command: $COMMAND"
else
    error_exit "You need to specify a command"
fi


		  
### setup verbose mode
# Nifty Trick found on SO
# You can write your own verbose only
# log string by repacing your
# echo "text string here"
# with
# echo "text string here" >&3
# for stdout (verbose)
# and >&4 for stderr (verbose)
###
if [ "$VERBOSE" = 1 ]; then
    exec 4>&2 3>&1
else
    exec 4>/dev/null 3>/dev/null
fi



### Check Basic Permissions 
if [[ $DRY_RUN == "NO" \
	    && ! -r $TARGET_DIR \
	    && ! -r $DATA_DIR \
	    && ! -r $CONF_DIR \
    ]];
then
    
    error_exit "Missing Required Dirs or No Read Access  $TARGET_DIR, $DATA_DIR, or  $CONF_DIR"
    
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

###
### We define a "shell environment api"
### that we source from the service file
### a docker-compose style override is also checked
###
### We check for some basic required variables 
###

if [ -e  $SERVICE_FILE ] ; then
    source $SERVICE_FILE
fi

if [ -e $SERVICE_FILE.override ] ; then
    source $SERVICE_FILE.override
fi


if [[  -z  $SERVICE_INIT_FN \
	    || -z $SERVICE_DESTROY_FN \
	    || -z $SERVICE_TEST \
    ]] ; then

    
    echo "Malformed Service File $SERVICE_FILE : Missing Required Variables"    
fi

    

# our docker-compose yml file for service deployments
SERVICE_DEPLOY_YML=${SERVICE_DEPLOY_YML-"./docker-service.yml"}

# the target path/name of the compose yml
SERVICE_DEPLOYMENT=$TARGET_DIR/$SERVICE_NAME.yml

# service specific data directory
SERVICE_DATA=$DATA_DIR/$SERVICE_NAME

# Service configurations live in subdir of CONF_DIR
SERVICE_CONFIG_ROOT=$CONF_DIR/service.d
SERVICE_CONFIG=$SERVICE_CONFIG_ROOT/$SERVICE_NAME.service



cat <<EOF >&3
---------------------debug-------------------------
compose-service service specific configuration
            service name: $SERVICE_NAME
             service yml: $SERVICE_DEPLOY_YML
      service deployment: $SERVICE_DEPLOYMENT
---------------------------------------------------
EOF



##########################################################
### Deployment Functions #################################
##########################################################


#
# Each command supported has an associated function
#   do_command
#
# and possibly a few helper functions
# the following is organized by major command
#
# deploy
# install-initd
# install-cron
# install-compose
# update
# remove
# destroy
#


######
###### DO_DEPLOY
######

function prep_deployment
{
    #----------------------------------------
    # Check for old content and create service folders
    # if necessary
    #
    # Outcome - all primary compose-service
    # folders - config, target, data
    # exist and are clean to be used
    # this function may fail in circumstances
    # when we should not be deploying , e.g.
    # if certain files exist when we try
    # to deploy (and arent using -f/--force)
    #----------------------------------------

    #likely never gets used
    if [[ ! -d $CONF_DIR && $FORCE != YES ]]; then
	error_exit "Cannot Deploy $SERVICE_NAME, Configuration Directory $CONF_DIR doesn't exist or isn't a directory"
    fi

    if [[ ! -d $SERVICE_CONFIG_ROOT ]]; then
	echo "First configured deployment Creating Service dir $SERVICE_CONFIG_ROOT" >&3	
	if [[ $DRY_RUN = NO ]]; then
	    mkdir -p $SERVICE_CONFIG_ROOT
	else
	    echo "-dry-run- mkdir -p $SERVICE_CONFIG_ROOT"
	fi
    fi


    #------------
    # Check Data Directory
    #------------
    if [[ ! -d $DATA_DIR ]]; then
	error_exit "Cannot Deploy $SERVICE_NAME, Data Root Directory $DATA_DIR doesn't exist or isn't a directory"
    fi

    #------------
    # Check for Target Dir
    #------------
    if [[ ! -d $TARGET_DIR ]]; then
	error_exit "Cannot Deploy $SERVICE_NAME, Target Dir $TARGET_DIR doesn't exist"
    fi


    #------------
    # Create our service root
    #------------
    if [[ -d $SERVICE_DATA ]]; then
	echo "-debug- Service Data Folder $SERVICE_DATA exists" >&3
    else
	run_dry mkdir -p $SERVICE_DATA
    fi


    #-----------
    # Check for pre-existing config/deployment files
    # fail if they exist and not forced
    #-----------
    
    if [[ -e $SERVICE_DEPLOYMENT && $FORCE != YES ]]; then
	error_exit "Cannot Deploy $SERVICE_NAME Deployment : $SERVICE_DEPLOYMENT exists  - use update or --force"
    fi


    if [[ -e $SERVICE_CONFIG && $FORCE != YES ]]; then
	error_exit "Cannot deploy $SERVICE_NAME Deployment Configuration File : $SERVICE_CONFIG exists - use update or --force"
    fi

    return 0
}

function prep_config
{

    # save absolute dir in our config
    CONF=$(cat <<-EOF
SERVICE_NAME=$SERVICE_NAME
SERVICE_TARGET_ROOT=`cd $TARGET_DIR; pwd`
SERVICE_COMPOSE=`cd $TARGET_DIR;pwd`/$SERVICE_NAME.yml
SERVICE_DATA_ROOT=`cd $DATA_DIR;pwd`
SERVICE_DATA_DIR=`cd $DATA_DIR;pwd`/$SERVICE_NAME
EOF
	)

    cat <<EOF >&3
---------------------debug-------------------------
$CONF
---------------------------------------------------
EOF
   

    if [[ $DRY_RUN = NO ]]; then
	cat <<-EOF > $SERVICE_CONFIG
$CONF
EOF
    else
	echo "-dry-run- echo $CONF > $SERVICE_CONFIG"
    fi


    return 0
}

function do_deploy
{
    prep_deployment
    prep_config
    
    
    if [[ ! -z $SERVICE_DEPLOY_YML || $SERVICE_INIT_FN ]]; then

	if [[ -e $SERVICE_INIT_FN ]]; then
	    echo "-debug- using SERVICE_INIT_FN to initialize yml data" >&3
	    YML_DATA=$SERVICE_INIT_FN
	else
	    echo "No Service Specific Init Function, using compose YML as is"
	    YML_DATA=$(cat $SERVICE_DEPLOY_YML)
	fi

	cat <<-EOF >&3
-------------------debug-----------------
$YML_DATA
-----------------------------------------
EOF
	
	if [[ $DRY_RUN = NO ]]; then
	    cat <<-EOF >  $SERVICE_DEPLOYMENT
$YML_DATA
EOF
	else
	    echo "-dry-run- cat \$YML_DATA > $SERVICE_DEPLOYMENT"
	fi
    else
	error_exit "Service Defintion does not define deploy files"
    fi

    return 0
    

}



#######
####### do_install_initd
#######

### Initd Locals
INITD_INSTALL_DIR=/etc/init.d
SERVICE_INITD_INSTALL=$INITD_INSTALL_DIR/$SERVICE_NAME

# Deploy init_d service files
function prep_initd_service
{
    
    if [[ -e $SERVICE_INITD_INSTALL ]]; then
	error_exit "init_d service for $SERVICE_NAME already exists"
    fi


    # po'mans templating
    
    initd_data=$(cat <<-EOF
#!/bin/sh
### BEGIN INIT INFO
# Provides:		$SERVICE_NAME
# Required-Start:	\$docker
# Required-Stop:	\$docker
# Default-Start:	2 3 4 5
# Default-Stop:		0 1 6
# Short-Description:	compose-service for $SERVICE_NAME
### END INIT INFO

set -e

SERVICE_NAME=$SERVICE_NAME
SERVICE_CONFIG=$SERVICE_CONFIG
SERVICE_DATA=$SERVICE_DATA
SERVICE_DEPLOYMENT=$SERVICE_DEPLOYMENT

OPTS="-f \$SERVICE_DEPLOYMENT -p \$SERVICE_NAME "

UPOPTS="-d --no-recreate --no-build --no-deps"
 
. /lib/lsb/init-functions

case "\$1" in
    start)
        log_daemon_msg "Starting compose-service" "\$SERVICE_NAME" ||  true
        docker-compose \$OPTS up \$UPOPTS
        ;;

    stop)
        log_daemon_msg "Stopping compose-service" "\$SERVICE_NAME" || true
        docker-compose \$OPTS stop
        ;;

    reload)
        log_daemon_msg "Reloading compose-service" "\$SERVICE_NAME" || true
        docker-compose \$OPTS up \$UPOPTS
        ;;

    restart)
        log_daemon_msg "Restarting compose-service" "\$SERVICE_NAME" || true
        docker-compose \$OPTS stop
        docker-compose \$OPTS up \$UPOPTS
        ;;

    recreate)
        log_daemon_msg "Recreating compose-service" "\$SERVICE_NAME" || true
        docker-compose \$OPTS down
        docker-compose \$OPTS up \$UPOPTS
        ;;

    *)
        log_action_msg "Usage: /etc/init.d/composegogs {start|stop|restart|reload|recreate}" || true
        exit 1
        ;;
esac

exit 0
EOF
		)


    # repeated cats but who cares I like cats
    
    cat <<-EOF >&3
--------debug-------$SERVICE_NAME---initd-data----------
$initd_data
----------------------------------------------------------
EOF

    
    if [[ $DRY_RUN = NO ]]; then
	cat <<-EOF > $SERVICE_INITD_INSTALL
$initd_data
EOF
    else
	cat <<-EOF
--dry-run---cat > $SERVICE_INITD_INSTALL
$initd_data
EOF
    fi

    run_dry chmod +x $SERVICE_INITD_INSTALL
    
    #update-rc.d $SERVICE_NAME defaults
    
    return 0
}


function destroy_initd_service
{
    return 0
}



function do_install_initd
{
    
    if [[ $DRY_RUN == "NO" \
		&& -w $SERVICE_INITD_INSTALL_DIR \
	]]; then
	error_exit "Run initd install with sudo pleaseWrite Access to /etc/init.d to install service"
    fi

    prep_initd_service
    

    
    return 0
}








#######
####### do_install_cron
#######





function do_install_cron
{
    return 0
}








#######
####### do_install_compose
#######


function do_install_compose
{
    return 0
}



function do_update
{
    return 0
}








#######
####### do_remove
#######



function do_remove
{
    if [[ -e  $SERVICE_DEPLOYMENT ]]; then
	echo "Removing Service Deployment $SERVICE_DEPLOYMENT"
	run_dry rm $SERVICE_DEPLOYMENT
    else
	echo "No Service Deployment Found"
    fi

    
    if [[ -e $SERVICE_CONFIG ]]; then
       echo "Removing Service Configuration $SERVICE_CONFIG"
       run_dry rm $SERVICE_CONFIG
    else
	echo "No Service Config Found"
    fi

    
    return 0
}






#######
####### do_destroy
#######



function do_destroy
{
    if [[ $FORCE = NO ]] ; then
	error_exit "Use the --force , Luke"
    fi

    do_remove

    if [[ -d $SERVICE_DATA ]] ; then
	read -p  "About To Destroy Service Data: $SERVICE_DATA - PRESS ENTER TO CONFIRM"
	run_dry rm -rf $SERVICE_DATA
    else
	echo "Service Data $SERVICE_DATA Doesn't Exist"
    fi
}

##########################################
### Peform Command########################
##########################################


case $COMMAND in
    deploy)
	echo "Deploying compose-service $SERVICE_NAME"
	do_deploy
	;;
    install-initd)
	echo "Installing compose-service $SERVICE_NAME as init.d service under system root"
	do_install_initd
	;;
    install-cron)
	echo "Installing compose-service $SERVICE_NAME as crontab under current user $USER"
	do_install_cron
	;;
    install-compose)
	echo "Installing  compose-service $SERVICE_NAME under compose-service umbrella"
	do_install_compose
	;;
    update)
	echo "Updating compose-service $SERVICE_NAME"
	do_update
	;;
    remove)
	echo "Removing compose-service $SERVICE_NAME (Will Not Destroy Data)"
	do_remove
	;;
    destroy)
	echo "Destroying compose-service $SERVICE_NAME"
	do_destroy
	;;
    *)
	error_exit "compose-service :: $COMMAND - Unknown Command"
	;;
esac		
