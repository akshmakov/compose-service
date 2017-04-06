#!/bin/bash
# install compose-service utility
#


DRY_RUN=${DRY_RUN-NO}
COMPOSE_SERVICE_TARGET_DIR=${COMPOSE_SERVICE_TARGET_DIR-/var/opt/compose-service/deploy}
COMPOSE_SERVICE_DATA_DIR=${COMPOSE_SERVICE_DATA_DIR-/var/opt/compose-service/data}
COMPOSE_SERVICE_CONFIG_DIR=${COMPOSE_SERVICE_CONFIG_DIR-/etc/compose-service}
COMPOSE_SERVICE_BIN=${COMPOSE_SERVICE_BIN-/usr/local/bin/compose-service}


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


function do_pop_env_header
{
    env_header=$(cat <<-EOF
#!/bin/bash
#------ INSTALL HEADER ------
COMPOSE_SERVICE_TARGET_DIR=$COMPOSE_SERVICE_TARGET_DIR
COMPOSE_SERVICE_DATA_DIR=$COMPOSE_SERVICE_DATA_DIR
COMPOSE_SERVICE_CONFIG_DIR=$COMPOSE_SERVICE_CONFIG_DIR
#------ FILE CONTINUES ------
EOF
	      )
    
    if [[ $DRY_RUN = NO ]]; then
	cat <<EOF > $COMPOSE_SERVICE_BIN
$env_header
EOF
    else
	cat <<EOF 
----dry-run---- cat > $COMPOSE_SERVICE_BIN
$env_header
EOF
    fi

    return 0
	
}


function do_create_dirs
{
    run_dry mkdir -p $COMPOSE_SERVICE_TARGET_DIR
    run_dry mkdir -p $COMPOSE_SERVICE_DATA_DIR
    run_dry mkdir -p $COMPOSE_SERVICE_CONFIG_DIR
}

function do_uninstall
{
    run_dry rm -rf $COMPOSE_SERVICE_TARGET_DIR
    run_dry rm -rf $COMPOSE_SERVICE_DATA_DIR
    run_dry rm -rf $COMPOSE_SERVICE_CONFIG_DIR
    run_dry rm $COMPOSE_SERVICE_BIN
}

function do_install
{
    echo "Installing compose-service"
    do_create_dirs 
    run_dry touch $COMPOSE_SERVICE_BIN
    do_pop_env_header
    run_dry "$(cat compose-service.sh >> $COMPOSE_SERVICE_BIN)"
    run_dry chmod +x $COMPOSE_SERVICE_BIN
    exit 0
}


if [[ ! -z $SERVICE_DELETE ]]; then
    do_uninstall
else
    do_install
fi
