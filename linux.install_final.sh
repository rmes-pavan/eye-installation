#!/bin/bash
refreshPermissions () {
    local pid="${1}"

    while kill -0 "${pid}" 2> /dev/null; do
        sudo -v
        sleep 10
    done
}

#Postgres/Ngnix/Dotnet
if psql -V | grep "PostgreSQL";then
  echo -e "\e[1;32m ==========Postgresql already installed========== \e[0m"
  present_working_dir=$(pwd)
  #echo "$present_working_dir"
  echo "Want to use old config [y/n] "
  read response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
  then
    #To read the appsetting.json and get the already using database name and password
    cmd0=$(jq '.ConnectionStrings.PostgreConnection' /var/www/eye.api/appsettings.json | xargs )
    IFS=";" read -a cmd0 <<< $cmd0
    databasename=$(echo "${cmd0[2]}")
    IFS="=" read -a databasename <<< $databasename
    oldpassword=$(echo "${cmd0[4]}")
    IFS="=" read -a oldpassword <<< $oldpassword
    echo "---${databasename[1]}--- is the old config database"
    echo "---${oldpassword[1]}--- is the old config password"
    DbName=${databasename[1]}
    passw=${oldpassword[1]}
  else
    dbarray=$(sudo -S -u postgres psql -t -A -c "SELECT datname FROM pg_database WHERE datistemplate = false;")

    #To save multiline list to array and echo them in serial order
    SAVEIFS=$IFS
    IFS=$'\n'
    dbarray=($dbarray)
    IFS=$SAVEIFS
    echo -e "\e[1;36m Database List \e[0m"
    for ((i=0; i<${#dbarray[@]} ; i++ )); do
        echo "$i. ${dbarray[$i]}"
    done
    echo "Select one of the above database to be used"
    read db
    #Condition for checking the input is within the displayed file no or not
    if (( $db>$i ));then
      echo "Not a valid Input"
      exit 1
    fi
    DbName=${dbarray[$db]}

   #For Selecting the default password OR giving the new password
    echo -e "\e[1;36m Default Passwords List \e[0m"
    pword=(rmtest hotandcold)
    for ((i=0; i<${#pword[@]} ; i++ )); do
          echo "$i. ${pword[$i]}"
    done
    echo "Select one of the above password OR give the new password"
    read pass
    if [[ "$pass" == 0 ]];then
      passw=${pword[$pass]}
    elif [[ "$pass" == 1 ]];then
      passw=${pword[$pass]}
    else
      passw=$pass
    fi
  fi

else
  echo "The Installation is First Time Installation"
  echo "Updating and Upgrading the PC"
  #refreshPermissions "$$" & sudo apt-get update -y
  #refreshPermissions "$$" & sudo apt-get upgrade -y
  echo "Installing Postgresql/Ngnix/Dotnet"
  #Some Libraries require lib which are install later due to this the below libs dependencies also fails so that why running the package installion again
  #TODO Not a Good way to handle this
  refreshPermissions "$$" & sudo dpkg -i *.deb ; sudo dpkg -i *.deb
  refreshPermissions "$$" & sudo mkdir -p /opt/dotnet && sudo tar zxf aspnetcore-runtime-5.0.10-linux-x64.tar.gz -C /opt/dotnet
  refreshPermissions "$$" & sudo ln -s /opt/dotnet/dotnet /usr/bin
  refreshPermissions "$$" & sudo cp default.conf /etc/nginx/conf.d/
  refreshPermissions "$$" & sudo cp nginx.conf /etc/nginx/
  refreshPermissions "$$" & sudo service nginx restart
  echo "Creating User rmtest"
  refreshPermissions "$$" & sudo -u postgres createuser rmtest
  echo "Creating Database rmdb1"
  touch ~/.pgpass
  chmod 600 ~/.pgpass
  echo "127.0.0.1:5432:*:postgres:hotandcold" >> ~/.pgpass
  refreshPermissions "$$" & sudo -u postgres createdb rmdb1
  refreshPermissions "$$" & sudo -S sed -i "s/#shared_preload_libraries.*/shared_preload_libraries = \'timescaledb\'/g" /etc/postgresql/13/main/postgresql.conf
  refreshPermissions "$$" & sudo -S sed -i "s/#listen_addresses.*/listen_addresses = \'*\'/g" /etc/postgresql/13/main/postgresql.conf
  refreshPermissions "$$" & sudo -S sed -i "s/host    all             all             127.0.0.1\/32            md5*/host    all             all             0.0.0.0\/0            md5/g" /etc/postgresql/13/main/pg_hba.conf
  refreshPermissions "$$" & sudo -S -u postgres psql --command " alter user rmtest with encrypted password 'hotandcold'; "
  refreshPermissions "$$" & sudo -S -u postgres psql --command " alter user postgres with encrypted password 'hotandcold'; "
  refreshPermissions "$$" & sudo -S -u postgres psql --command " grant all privileges on database rmdb1 to rmtest; "
  refreshPermissions "$$" & sudo -S -u postgres psql --command " CREATE EXTENSION IF NOT EXISTS pgagent "
  refreshPermissions "$$" & sudo service postgresql restart
  pg_restore -h localhost -U postgres -d rmdb1 -W -v "R_U_S_Unit_Protocol_DF.backup"
  pgagent hostaddr=127.0.0.1 port=5432 dbname=postgres user=postgres
  DbName=rmdb1
  echo "@reboot pgagent hostaddr=127.0.0.1 port=5432 dbname=postgres user=postgres
@reboot ~/gw-rmon/bins/watchdog-rmon > /dev/null 2>&1 &" | crontab -
fi

#RM Gateway Software Installation
if [ -f ~/gw-rmon/bins/watchdog-rmon ]; then
  ver=$(~/gw-rmon/bins/vers-rmon)
  echo -e "\e[1;32m ==========RM Gateway Software Version $ver already installed========== \e[0m"
  if ps ax | pgrep watchdog-rmon ;then
    echo -e "\e[1;32m ==========Watchdog-rmon is running========== \e[0m"
  else
    echo -e "\e[1;31m ==========Watchdog-rmon is not running========== \e[0m"
  fi
else
  mkdir ~/rmontmp
  #mv ~/v-0-55-2021-10-13-rmon-gw-x86-bundle.tar.gz ~/rmontmp/
  tar xvfz v-0-163-2023-01-20-rmon-gw-x86-bundle.tar.gz -C ~/rmontmp/ ; refreshPermissions "$$" & sudo ~/rmontmp/./install-rmon.sh
fi

#RM UI software installation
# Stopping and Removing the Services
services=(eye eyeapi eyenotify eyescheduler eyedga eyeanalyticsBT eyeanalyticsMIO eyeanalyticsMIP eyeanalyticsOLC eyeanalyticsRL eyeanalyticsWHS eyereport eyeanalyticsHI eyeanalyticsHIDGA eyecalc eyetpcalc eyestandardanalyticengine eyetimeranalyticengine eyedataimporter)
for ((i=0; i<${#services[@]} ; i++ )); do
  if [ -f /etc/systemd/system/kestrel-${services[$i]}.service ]; then
    echo -e "\e[1;32m ==========Stopping ${services[$i]}-service========== \e[0m"
    refreshPermissions "$$" & sudo service kestrel-${services[$i]} stop
    echo -e "\e[1;32m ==========Kestral-${services[$i]}.service is stopped========== \e[0m"
    refreshPermissions "$$" & sudo rm /etc/systemd/system/kestrel-${services[$i]}.service
    echo -e "\e[1;32m ==========Removed kestrel-${services[$i]}.service========== \e[0m"
  else
    echo -e "\e[1;31m ==========Kestrel-${services[$i]}.service not installed========== \e[0m"
  fi
done

#Removing & Copying files
build_folder=(communicator notifier scheduler dga analyticsHI analyticsBT analyticsMIO analyticsMIP analyticsOLC analyticsRL analyticsWHS  analyticsHIDGA commoncal tpcalculator standardanalyticengine timeranalyticengine dataimporter)
for ((i=0; i<${#build_folder[@]} ; i++ )); do
  #Removing communicator, notifier and scheduler files
  refreshPermissions "$$" & sudo rm -rf /srv/eye.${build_folder[$i]}/
  if [ -f /srv/eye.${build_folder[$i]}/appsettings.json ];then
    echo -e "\e[1;31m Failed to remove Eye.${build_folder[$i]} \e[0m"
  else
    echo -e "\e[1;31m Eye.${build_folder[$i]} folder Not Present \e[0m"
  fi
  #Copying communicator, notifier and scheduler files
  refreshPermissions "$$" & sudo cp -r ${present_working_dir}/eye.${build_folder[$i]}/ /srv/
  refreshPermissions "$$" & sudo chown root -R /srv/eye.${build_folder[$i]}/
  if [ -f /srv/eye.${build_folder[$i]}/appsettings.json ];then
    echo -e "\e[1;32m Eye.${build_folder[$i]} copied sucessfully \e[0m"
  else
    echo -e "\e[1;31m Failed to copy Eye.${build_folder[$i]} \e[0m"
  fi
done

#Removing Eye-Reports-UI
cd ${present_working_dir}/eye-reports-ui ; npm i --save ; npm audit fix --force
cd ${present_working_dir}
refreshPermissions "$$" & sudo rm -rf /srv/eye-reports-ui/
refreshPermissions "$$" & sudo cp -r ${present_working_dir}/eye-reports-ui/ /srv/
refreshPermissions "$$" & sudo chown root -R /srv/eye-reports-ui/

#Removing UI files
refreshPermissions "$$" & sudo rm -rf /var/www/eye-ui/
if [ -f /var/www/eye-ui/assets/config.js ];then
  echo -e "\e[1;31m Failed to remove Eye-ui \e[0m"
else
  echo -e "\e[1;31m Eye-ui folder Not Present /var/ folder \e[0m"
fi
#Copping UI files
refreshPermissions "$$" & sudo cp -r ${present_working_dir}/eye-ui/ /var/www/
if [ -f /var/www/eye-ui/assets/config.js ];then
  echo -e "\e[1;32m Eye-ui copied sucessfully \e[0m"
else
  echo -e "\e[1;31m Failed to copy Eye-ui \e[0m"
fi

#Removing Api files
refreshPermissions "$$" & sudo rm -rf /var/www/eye.api/
if [ -f /var/www/eye.api/appsettings.json ];then
  echo -e "\e[1;31m Failed to remove Eye.api \e[0m"
else
  echo -e "\e[1;31m Eye.api folder Not Present at /var/ folder \e[0m"
fi
#Copping Api files
refreshPermissions "$$" & sudo cp -r ${present_working_dir}/eye.api/ /var/www/
if [ -f /var/www/eye.api/appsettings.json ];then
  echo -e "\e[1;32m Eye.api copied sucessfully \e[0m"
else
  echo -e "\e[1;31m Failed to copy Eye.api \e[0m"
fi

#Coping maps to the eye-ui
if [ -f ~/maps/hyderabad_tiles/OSMPublicTransport/10/734/460.png ]; then
  echo -e "\e[1;32m ==========Coping Maps to Eye-ui ========== \e[0m"
  refreshPermissions "$$" & sudo cp -r ~/maps/ /var/www/eye-ui/assets/
else
  echo -e "\e[1;31m ==========Maps are not present========== \e[0m"
fi

#For checking the /srv/service Folder
build_folder=(communicator notifier scheduler )
for ((i=0; i<${#build_folder[@]} ; i++ )); do
  if [ -f /srv/eye.${build_folder[$i]}/appsettings.json ]; then
    continue
  else
    echo -e "\e[1;31m Eye.${build_folder[$i]} files are not present \e[0m"
    exit 1
  fi
done

#For Checking the /var/www/ folders
build_folder=(/var/www/eye.api/appsettings.json /var/www/eye-ui/assets/config.js)
for ((i=0; i<${#build_folder[@]} ; i++ )); do
  if [ -f ${build_folder[$i]} ]; then
    continue
  else
    echo -e "\e[1;31m Eye${build_folder[$i]} files are not present \e[0m"
    exit 1
  fi
done

#Reading the .json files and changing the database name and the password for api and quartz
json_files=(/var/www/eye.api/appsettings.Development.json /var/www/eye.api/appsettings.json /srv/eye.scheduler/quartz.config)
for ((i=0; i<${#json_files[@]} ; i++ )); do
  if [ ${json_files[$i]} == "/srv/eye.scheduler/quartz.config" ]; then
    cmd1=$(sed -n '6p' /srv/eye.scheduler/quartz.config)
  else
    cmd1=$(jq '.ConnectionStrings.PostgreConnection' ${json_files[$i]} | xargs )
  fi
  IFS=";" read -a cmd1 <<< $cmd1
  databasename=$(echo "${cmd1[2]}")
  IFS="=" read -a databasename <<< $databasename
  oldpassword=$(echo "${cmd1[4]}")
  IFS="=" read -a oldpassword <<< $oldpassword
  refreshPermissions "$$" & sudo sed -i "s/Database=${databasename[1]}/Database=$DbName/g" ${json_files[$i]}
  refreshPermissions "$$" & sudo sed -i "s/Password=${oldpassword[1]}/Password=$passw/g" ${json_files[$i]}
done

#Reading the .json files and changing the database name and the password for services
file_type=(appsettings.Development.json appsettings.json)
for ((i=0; i<${#file_type[@]} ; i++ )); do
  #TODO Change the name of the service Array
    services=(communicator notifier scheduler dga analyticsHI analyticsBT analyticsMIO analyticsMIP analyticsOLC analyticsRL analyticsWHS  analyticsHIDGA commoncal tpcalculator standardanalyticengine timeranalyticengine dataimporter)
    for ((j=0; j<${#services[@]} ; j++ )); do
      #echo "${services[$j]},,,,,${file_type[$i]}"
      cmd2=$(jq '.ConnectionStrings.PostgreConnection' /srv/eye.${services[$j]}/${file_type[$i]} | xargs )
      IFS=";" read -a cmd1 <<< $cmd2
      databasename=$(echo "${cmd1[2]}")
      IFS="=" read -a databasename <<< $databasename
      oldpassword=$(echo "${cmd1[4]}")
      IFS="=" read -a oldpassword <<< $oldpassword
      refreshPermissions "$$" & sudo sed -i "s/Database=${databasename[1]}/Database=$DbName/g" /srv/eye.${services[$j]}/${file_type[$i]}
      refreshPermissions "$$" & sudo sed -i "s/Password=${oldpassword[1]}/Password=$passw/g" /srv/eye.${services[$j]}/${file_type[$i]}
    done
done

#TODO To replace the filepath  for all paths/ All the paths will be removed but there will be 3 Filepath inputs needed to do so the following solution can be used
#refreshPermissions "$$" & sudo sed -i '73s/.*/    \"Filepath1\": "expected_path1"/g' appsettings.Development.json
#refreshPermissions "$$" & sudo sed -i "/\"Filepath1/c\    \"Filepath\": \"${expected_path}\"" appsettings.Development.json
#TODO But for now replacing all the filepath with common path
cmd2=$(whoami)
expected_path=/home/$cmd2/gw-rmon/datafiles/
refreshPermissions "$$" & sudo sed -i "/.*Filepath.*/c\    \"Filepath\": \"${expected_path}\"" /var/www/eye.api/appsettings.Development.json # For Changing the Other FilePaths
refreshPermissions "$$" & sudo sed -i "/\"FilePath/c\    \"FilePath\": \"${expected_path}\"" /var/www/eye.api/appsettings.Development.json #Only for changing the PRPD FilePath

#Steps For Configuring Reports
#killall node
mkdir ~/gw-rmon/datafiles ; mkdir ~/gw-rmon/datafiles/reports
expected_path=/home/$cmd2/gw-rmon/datafiles/reports
#refreshPermissions "$$" & sudo sed -i "/REPORT_FOLDER.*/cREPORT_FOLDER='${expected_path}'" ${present_working_dir}/eye-reports-ui/.env
#refreshPermissions "$$" & sudo sed -i "/API_URL.*/cAPI_URL='http://localhost/api/CustomReports'" ${present_working_dir}/eye-reports-ui/.env
#TODO nohup command should be run on reboot? if yes then it should be handled diferently as for now the reports comes with build
#nohup node ./bin/www &

#Reading the IP address of the PC
IP=$(ifconfig | grep "inet ")
IFS=" " read -a IP <<< $IP
#echo "${IP[1]}"
#Changing the ipaddress in the config.js file
refreshPermissions "$$" & sudo sed -i "2s/.*/      API_URL: 'http:\/\/${IP[1]}\/api',/g" /var/www/eye-ui/assets/config.js
refreshPermissions "$$" & sudo sed -i "3s/.*/      WS_URL: 'http:\/\/${IP[1]}\/notify',/g" /var/www/eye-ui/assets/config.js

#Coping the Service
services=(eye eyeapi eyenotify eyescheduler eyedga eyeanalyticsBT eyeanalyticsMIO eyeanalyticsMIP eyeanalyticsOLC eyeanalyticsRL eyeanalyticsWHS eyereport eyeanalyticsHI eyeanalyticsHIDGA eyecalc eyetpcalc eyestandardanalyticengine eyetimeranalyticengine eyedataimporter)
for ((i=0; i<${#services[@]} ; i++ )); do
  refreshPermissions "$$" & sudo cp services/kestrel-${services[$i]}.service /etc/systemd/system/
  if [ -f /etc/systemd/system/kestrel-${services[$i]}.service ];then
    echo -e "\e[1;32m Copied the kestral-${services[$i]}.service \e[0m"
  else
    echo -e "\e[1;31m Failed to copy kestral-${services[$i]}.service \e[0m"
  fi
done

#To Enable the Service
refreshPermissions "$$" & sudo systemctl daemon-reload
services=(eye eyeapi eyenotify eyescheduler eyedga eyeanalyticsBT eyeanalyticsMIO eyeanalyticsMIP eyeanalyticsOLC eyeanalyticsRL eyeanalyticsWHS eyereport eyeanalyticsHI eyeanalyticsHIDGA eyecalc eyetpcalc eyestandardanalyticengine eyetimeranalyticengine eyedataimporter)
for ((i=0; i<${#services[@]} ; i++ )); do
  refreshPermissions "$$" & sudo systemctl enable kestrel-${services[$i]}.service
done
echo -e "\e[1;32m Daemon-reload completed \e[0m"

#To start the Service
services=(eye eyeapi eyenotify eyescheduler eyedga eyeanalyticsBT eyeanalyticsMIO eyeanalyticsMIP eyeanalyticsOLC eyeanalyticsRL eyeanalyticsWHS eyereport eyeanalyticsHI eyeanalyticsHIDGA eyecalc eyetpcalc eyestandardanalyticengine eyetimeranalyticengine eyedataimporter)
for ((i=0; i<${#services[@]} ; i++ )); do
  refreshPermissions "$$" & sudo service kestrel-${services[$i]} start
done

#Checking the status of Service
services=(eye eyeapi eyenotify eyescheduler eyedga eyeanalyticsBT eyeanalyticsMIO eyeanalyticsMIP eyeanalyticsOLC eyeanalyticsRL eyeanalyticsWHS eyereport eyeanalyticsHI eyeanalyticsHIDGA eyecalc eyetpcalc eyestandardanalyticengine eyetimeranalyticengine eyedataimporter)
for ((i=0; i<${#services[@]} ; i++ )); do
  eyestatus=$(sudo service kestrel-${services[$i]} status | grep Active:)
  SAVEIFS=$IFS
  IFS=$' '
  eyestatus=($eyestatus)
  IFS=$SAVEIFS
  #echo "${eyestatus[1]}"
  if [[ "${eyestatus[1]}" == "active" ]];then
    echo -e "\e[1;32m Kestral.${services[$i]} service is running \e[0m"
  else
    echo -e "\e[1;31m Kestral.${services[$i]} service is not running \e[0m"
  fi
done