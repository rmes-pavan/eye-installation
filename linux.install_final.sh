#!/bin/bash
refreshPermissions () {
    local pid="${1}"

    while kill -0 "${pid}" 2> /dev/null; do
        sudo -v
        sleep 10
    done
}

#Postgres/Ngnix/Dotnet

if psql -V | grep "13";then
  echo -e "\e[1;32m ==========Postgresql already installed========== \e[0m"
  present_working_dir=$(pwd)
  #echo "$present_working_dir"
  read -r -p "Want to use old config [y/n] " response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
  then
      #To read the appsetting.json and get the already using database name and password
      cmd=$(jq '.ConnectionStrings.PostgreConnection' /var/www/eye.api/appsettings.json | xargs )
      IFS=";" read -a cmd <<< $cmd
      databasename=$(echo "${cmd[2]}")
      IFS="=" read -a databasename <<< $databasename
      oldpassword=$(echo "${cmd[4]}")
      IFS="=" read -a oldpassword <<< $oldpassword
      echo "---${databasename[1]}--- is the old config database"
      echo "---${oldpassword[1]}--- is the old config password"
      DbName=${databasename[1]}
      passw=${oldpassword[1]}
  else
      dbarray=$(sudo -S -u postgres psql -t -A -c "SELECT datname FROM pg_database WHERE datname <> ALL ('{template0,template1,postgres}')")

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
      DbName=${dbarray[$db]}
      #echo "${dbarray[$db]}"

     #For Selecting the default password OR giving the new password
      echo -e "\e[1;36m Default Passwords List \e[0m"
      pword=(rmtest,hotandcold)
      IFS="," read -a pword <<< $pword;
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
  refreshPermissions "$$" & sudo apt-get update -y
  refreshPermissions "$$" & sudo apt-get upgrade -y
  echo "Installing Postgresql/Ngnix/Dotnet"
  refreshPermissions "$$" & sudo dpkg -i *.deb
  refreshPermissions "$$" & sudo mkdir -p /opt/dotnet && sudo tar zxf aspnetcore-runtime-5.0.10-linux-x64.tar.gz -C /opt/dotnet
  refreshPermissions "$$" & sudo ln -s /opt/dotnet/dotnet /usr/bin
  refreshPermissions "$$" & sudo cp default.conf /etc/nginx/conf.d/
  refreshPermissions "$$" & sudo cp nginx.conf /etc/nginx/
  refreshPermissions "$$" & sudo service nginx restart
  echo "Creating User rmtest"
  refreshPermissions "$$" & sudo -u postgres createuser rmtest
  #refreshPermissions "$$" & sudo -u postgres createuser rmuser1
  echo "Creating Database rmdb1"
  #refreshPermissions "$$" & sudo timescaledb-tune
  touch ~/.pgpass
  chmod 600 ~/.pgpass
  echo "127.0.0.1:5432:*:postgres:hotandcold" >> ~/.pgpass
  refreshPermissions "$$" & sudo -u postgres createdb rmdb1
  refreshPermissions "$$" & sudo -S sed -i "s/#shared_preload_libraries.*/shared_preload_libraries = \'timescaledb\'/g" /etc/postgresql/13/main/postgresql.conf
  refreshPermissions "$$" & sudo -S sed -i "s/#listen_addresses.*/listen_addresses = \'*\'/g" /etc/postgresql/13/main/postgresql.conf
  refreshPermissions "$$" & sudo -S sed -i "s/host    all             all             127.0.0.1\/32            md5*/host    all             all             0.0.0.0\/0            md5/g" /etc/postgresql/13/main/pg_hba.conf
  #refreshPermissions "$$" & sudo cp services/postgresql.conf /etc/postgresql/13/main/
  #refreshPermissions "$$" & sudo cp services/pg_hba.conf /etc/postgresql/13/main/
  refreshPermissions "$$" & sudo -S -u postgres psql --command " alter user rmtest with encrypted password 'hotandcold'; "
  refreshPermissions "$$" & sudo -S -u postgres psql --command " alter user postgres with encrypted password 'hotandcold'; "
  #refreshPermissions "$$" & sudo -S -u postgres psql --command " alter user rmuser1 with encrypted password 'hotandcold'; "
  refreshPermissions "$$" & sudo -S -u postgres psql --command " grant all privileges on database rmdb1 to rmtest; "
  #refreshPermissions "$$" & sudo -S -u postgres psql --command " grant all privileges on database rmdb1 to rmuser1; "
  refreshPermissions "$$" & sudo -S -u postgres psql --command " CREATE EXTENSION IF NOT EXISTS pgagent "
  refreshPermissions "$$" & sudo service postgresql restart
  pg_restore -h localhost -p 5432 -U postgres -d rmdb1 -W -v "R_U_S_Unit_Protocol_DF.backup"
  pgagent hostaddr=127.0.0.1 port=5432 dbname=postgres user=postgres
  #echo "Backing up the database"
  #read data_base
  #pg_restore -h localhost -p 5432 -U postgres  -d rmdb1 -W -v $data_base
  #refreshPermissions "$$" & sudo service postgresql restart
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
  tar xvfz v-0-68-2021-12-06-rmon-gw-x86-bundle.tar.gz -C ~/rmontmp/ ; refreshPermissions "$$" & sudo ~/rmontmp/./install-rmon.sh
fi

#RM UI software installation
#Stopping and Removing the eye-service
if [ -f /etc/systemd/system/kestrel-eye.service ]; then
  echo -e "\e[1;32m ==========Stopping eye-service========== \e[0m"
  refreshPermissions "$$" & sudo service kestrel-eye stop
  echo -e "\e[1;32m ==========Kestral-eye.service is stopped========== \e[0m"
  refreshPermissions "$$" & sudo rm /etc/systemd/system/kestrel-eye.service
  echo -e "\e[1;32m ==========Removed kestrel-eye.service========== \e[0m"
else
  echo -e "\e[1;31m ==========Kestrel-eye.service not installed========== \e[0m"
fi

#Stopping and Removing the api.service
if [ -f /etc/systemd/system/kestrel-eyeapi.service ]; then
    echo -e "\e[1;32m ==========Stopping kestrel-eyeapi.service========== \e[0m"
    refreshPermissions "$$" & sudo service kestrel-eyeapi stop
    echo -e "\e[1;32m ==========Kestral-eyeapi.sevice is stoped========== \e[0m"
    refreshPermissions "$$" & sudo rm /etc/systemd/system/kestrel-eyeapi.service
    echo -e "\e[1;32m ==========Removed kestrel-eyeapi.service========== \e[0m"
else
  echo -e "\e[1;31m ==========Kestrel-eyeapi.service not installed========== \e[0m"
fi

#Stopping and Removing the notify.service
if [ -f /etc/systemd/system/kestrel-eyenotify.service ]; then
    echo -e "\e[1;32m ==========Stopping kestrel-eyenotify.service========== \e[0m"
    refreshPermissions "$$" & sudo service kestrel-eyenotify stop
    echo -e "\e[1;32m ==========Kestral-eyenotify.sevice is stoped========== \e[0m"
    refreshPermissions "$$" & sudo rm /etc/systemd/system/kestrel-eyenotify.service
    echo -e "\e[1;32m ==========Removed kestrel-eyenotify.service========== \e[0m"
else
  echo -e "\e[1;31m ==========Kestrel-eyenotify.service not installed========== \e[0m"
fi

#Stopping and Removing the scheduler.service
if [ -f /etc/systemd/system/kestrel-eyescheduler.service ]; then
    echo -e "\e[1;32m ==========Stopping kestrel-eyescheduler.service========== \e[0m"
    refreshPermissions "$$" & sudo service kestrel-eyescheduler stop
    echo -e "\e[1;32m ==========Kestral-eyescheduler.sevice is stoped========== \e[0m"
    refreshPermissions "$$" & sudo rm /etc/systemd/system/kestrel-eyescheduler.service
    echo -e "\e[1;32m ==========Removed kestrel-eyescheduler.service========== \e[0m"
else
  echo -e "\e[1;31m ==========Kestrel-eyescheduler.service not installed========== \e[0m"
fi


#Remove the Eye api, ui and service files
refreshPermissions "$$" & sudo rm -rf /srv/eye.communicator/
if [ -f /srv/eye.communicator/appsettings.json ];then
  echo -e "\e[1;31m Failed to remove Eye.service \e[0m"
else
  echo -e "\e[1;31m Eye.service not installed \e[0m"
fi

refreshPermissions "$$" & sudo rm -rf /srv/eye.notifier/
if [ -f /srv/eye.notifier/appsettings.json ];then
  echo -e "\e[1;31m Failed to remove Eye.notifier \e[0m"
else
  echo -e "\e[1;31m Eye.notifier not installed \e[0m"
fi

refreshPermissions "$$" & sudo rm -rf /srv/eye.scheduler/
if [ -f /srv/eye.scheduler/appsettings.json ];then
  echo -e "\e[1;31m Failed to remove Eye.scheduler \e[0m"
else
  echo -e "\e[1;31m Eye.scheduler not installed \e[0m"
fi

refreshPermissions "$$" & sudo rm -rf /var/www/eye-ui/
if [ -f /var/www/eye-ui/assets/config.js ];then
  echo -e "\e[1;31m Failed to remove Eye-ui \e[0m"
else
  echo -e "\e[1;31m Eye-ui not installed \e[0m"
fi

refreshPermissions "$$" & sudo rm -rf /var/www/eye.api/
if [ -f /var/www/eye.api/appsettings.json ];then
  echo -e "\e[1;31m Failed to remove Eye.api \e[0m"
else
  echo -e "\e[1;31m Eye.api not installed \e[0m"
fi

#Copying Eye api, ui and service files
refreshPermissions "$$" & sudo cp -r ${present_working_dir}/eye.communicator/ /srv/
if [ -f /srv/eye.communicator/appsettings.json ];then
  echo -e "\e[1;32m Eye.service copied sucessfully \e[0m"
else
  echo -e "\e[1;31m Failed to copy Eye.service \e[0m"
fi

refreshPermissions "$$" & sudo cp -r ${present_working_dir}/eye.notifier/ /srv/
if [ -f /srv/eye.notifier/appsettings.json ];then
  echo -e "\e[1;32m Eye.notifier copied sucessfully \e[0m"
else
  echo -e "\e[1;31m Failed to copy Eye.notifier \e[0m"
fi

refreshPermissions "$$" & sudo cp -r ${present_working_dir}/eye.scheduler/ /srv/
if [ -f /srv/eye.scheduler/appsettings.json ];then
  echo -e "\e[1;32m Eye.scheduler copied sucessfully \e[0m"
else
  echo -e "\e[1;31m Failed to copy Eye.scheduler \e[0m"
fi

refreshPermissions "$$" & sudo cp -r ${present_working_dir}/eye.api/ /var/www/
if [ -f /var/www/eye.api/appsettings.json ];then
  echo -e "\e[1;32m Eye.api copied sucessfully \e[0m"
else
  echo -e "\e[1;31m Failed to copy Eye.api \e[0m"
fi

refreshPermissions "$$" & sudo cp -r ${present_working_dir}/eye-ui/ /var/www/
if [ -f /var/www/eye-ui/assets/config.js ];then
  echo -e "\e[1;32m Eye-ui copied sucessfully \e[0m"
else
  echo -e "\e[1;31m Failed to copy Eye-ui \e[0m"
fi

#Coping maps to the eye-ui
if [ -f ~/maps/hyderabad_tiles/OSMPublicTransport/10/734/460.png ]; then
  echo -e "\e[1;32m ==========Coping Maps to Eye-ui ========== \e[0m"
  refreshPermissions "$$" & sudo cp -r ~/maps/ /var/www/eye-ui/assets/
else
  echo -e "\e[1;31m ==========Maps are not present========== \e[0m"
fi

if [ -f /srv/eye.communicator/appsettings.json ];then
  if [ -f /var/www/eye.api/appsettings.json ];then
    if [ -f /var/www/eye-ui/assets/config.js ];then
      if [ -f /srv/eye.notifier/appsettings.json ];then
        if [ -f /srv/eye.scheduler/appsettings.json ];then
          #Reading the .json files and changing the database name and the password
#         cmd=$(jq '.ConnectionStrings.PostgreConnection' /srv/eye.service/appsettings.json | xargs )
#         IFS=";" read -a cmd <<< $cmd
#         databasename=$(echo "${cmd[2]}")
#         IFS="=" read -a databasename <<< $databasename
#         oldpassword=$(echo "${cmd[4]}")
#         IFS="=" read -a oldpassword <<< $oldpassword
#         #echo "---${databasename[1]}--- database is currently in used"
#         refreshPermissions "$$" & sudo sed -i "s/Database=${databasename[1]}/Database=$DbName/g" /srv/eye.service/appsettings.json
#         refreshPermissions "$$" & sudo sed -i "s/Password=${oldpassword[1]}/Password=$passw/g" /srv/eye.service/appsettings.json
#
          cmd=$(jq '.ConnectionStrings.PostgreConnection' /var/www/eye.api/appsettings.json | xargs )
          IFS=";" read -a cmd <<< $cmd
          databasename=$(echo "${cmd[2]}")
          IFS="=" read -a databasename <<< $databasename
          oldpassword=$(echo "${cmd[4]}")
          IFS="=" read -a oldpassword <<< $oldpassword
          #echo "---${databasename[1]}--- database is currently in used"
          refreshPermissions "$$" & sudo sed -i "s/Database=${databasename[1]}/Database=$DbName/g" /var/www/eye.api/appsettings.json
          refreshPermissions "$$" & sudo sed -i "s/Password=${oldpassword[1]}/Password=$passw/g" /var/www/eye.api/appsettings.json

          cmd3=$(whoami)
          #echo "$cmd3 is the username"
          expected_path=/home/$cmd3/
          #echo "Expected path is $expected_path"
          #cmd5=$(jq '.UploadFilePath.FilePath' /var/www/eye.api/appsettings.Development.json | xargs)
          refreshPermissions "$$" & sudo sed -i 's/\"FilePath\":.*/\"FilePath\": \"$expected_path\"/g' /var/www/eye.api/appsettings.Development.json

          #jq '.userGeneration.VerificationUrlRoot' /var/www/eye.api/appsettings.Development.json | xargs

    #      cmd=$(jq '.ConnectionStrings.PostgreConnection' /srv/eye.service/appsettings.Development.json | xargs )
    #      IFS=";" read -a cmd <<< $cmd
    #      databasename=$(echo "${cmd[2]}")
    #      IFS="=" read -a databasename <<< $databasename
    #      oldpassword=$(echo "${cmd[4]}")
    #      IFS="=" read -a oldpassword <<< $oldpassword
    #      #echo "---${databasename[1]}--- database is currently in used"
    #      refreshPermissions "$$" & sudo sed -i "s/Database=${databasename[1]}/Database=$DbName/g" /srv/eye.service/appsettings.Development.json
    #      refreshPermissions "$$" & sudo sed -i "s/Password=${oldpassword[1]}/Password=$passw/g" /srv/eye.service/appsettings.Development.json

          cmd=$(jq '.ConnectionStrings.PostgreConnection' /var/www/eye.api/appsettings.Development.json | xargs )
          IFS=";" read -a cmd <<< $cmd
          databasename=$(echo "${cmd[2]}")
          IFS="=" read -a databasename <<< $databasename
          oldpassword=$(echo "${cmd[4]}")
          IFS="=" read -a oldpassword <<< $oldpassword
          #echo "---${databasename[1]}--- database is currently in used"
          refreshPermissions "$$" & sudo sed -i "s/Database=${databasename[1]}/Database=$DbName/g" /var/www/eye.api/appsettings.Development.json
          refreshPermissions "$$" & sudo sed -i "s/Password=${oldpassword[1]}/Password=$passw/g" /var/www/eye.api/appsettings.Development.json

          #Reading the IP address of the PC
          IP=$(ifconfig|grep 192.168.60)
          SAVEIFS=$IFS
          IFS=$' '
          IP=($IP)
          IFS=$SAVEIFS
          #echo "${IP[1]}"

          #Changing the ipaddress in the config.js file
          refreshPermissions "$$" & sudo sed -i "2s/.*/      API_URL: 'http:\/\/${IP[1]}\/api',/g" /var/www/eye-ui/assets/config.js
          refreshPermissions "$$" & sudo sed -i "3s/.*/      WS_URL: 'http:\/\/${IP[1]}\/notify'/g" /var/www/eye-ui/assets/config.js

          #Edit appsettings
          #refreshPermissions "$$" & sudo sed -i '22s/.*/    "PostgreConnection": "Host=localhost;Port=5432;Database=${DB};Username=rmtest;Password=hotandcold;Pooling=true;MinPoolSize=1;MaxPoolSize=95;ConnectionLifeTime=15;"/' /srv/eye.service/appsettings.json
          #refreshPermissions "$$" & sudo sed -i '22s/.*/    "PostgreConnection": "Host=localhost;Port=5432;Database=${DB};Username=rmtest;Password=hotandcold;Pooling=true;MinPoolSize=1;MaxPoolSize=95;ConnectionLifeTime=15;"/' /var/www/eye.api/appsettings.json
          #refreshPermissions "$$" & sudo sed -i '22s/.*/    "PostgreConnection": "Host=localhost;Port=5432;Database=${DB};Username=rmtest;Password=hotandcold;Pooling=true;MinPoolSize=1;MaxPoolSize=95;ConnectionLifeTime=15;"/' /var/www/eye.api/appsettings.Development.json
          #refreshPermissions "$$" & sudo sed -i '22s/.*/    "PostgreConnection": "Host=localhost;Port=5432;Database=${DB};Username=rmtest;Password=hotandcold;Pooling=true;MinPoolSize=1;MaxPoolSize=95;ConnectionLifeTime=15;"/' /srv/eye.service/appsettings.Development.json
          #refreshPermissions "$$" & sudo sed -i "2s/.*/      API_URL: 'http://${IP}/api'/" /var/www/eye-ui/assets/config.js
          #refreshPermissions "$$" & sudo sed -i "3s/.*/      WS_URL: 'http://${IP}/notify'/" /var/www/eye-ui/assets/config.js

          #Coping the kestral-service
          refreshPermissions "$$" & sudo cp services/kestrel-eyeapi.service /etc/systemd/system/
          if [ -f /etc/systemd/system/kestrel-eyeapi.service ];then
            echo -e "\e[1;32m Copied the kestral-eyeapi.service \e[0m"
          else
            echo -e "\e[1;31m Failed to copy kestral-eyeapi.service \e[0m"
          fi

          #Coping the eye-service
          refreshPermissions "$$" & sudo cp services/kestrel-eye.service /etc/systemd/system/
          if [ -f /etc/systemd/system/kestrel-eye.service ];then
            echo -e "\e[1;32m Copied the kestral-eye.service \e[0m"
          else
            echo -e "\e[1;31m Failed to copy kestral-eye.service \e[0m"
          fi

          #Coping the eye-notify
          refreshPermissions "$$" & sudo cp services/kestrel-eyenotify.service /etc/systemd/system/
          if [ -f /etc/systemd/system/kestrel-eyenotify.service ];then
            echo -e "\e[1;32m Copied the kestral-eye.notify \e[0m"
          else
            echo -e "\e[1;31m Failed to copy kestral-eye.notify \e[0m"
          fi

          #Coping the eye-scheduler
          refreshPermissions "$$" & sudo cp services/kestrel-eyescheduler.service /etc/systemd/system/
          if [ -f /etc/systemd/system/kestrel-eyescheduler.service ];then
            echo -e "\e[1;32m Copied the kestral-eye.scheduler \e[0m"
          else
            echo -e "\e[1;31m Failed to copy kestral-eye.scheduler \e[0m"
          fi

          refreshPermissions "$$" & sudo systemctl daemon-reload
          refreshPermissions "$$" & sudo systemctl enable kestrel-eyeapi.service
          refreshPermissions "$$" & sudo systemctl enable kestrel-eye.service
          refreshPermissions "$$" & sudo systemctl enable kestrel-eyenotify.service
          refreshPermissions "$$" & sudo systemctl enable kestrel-eyescheduler.service
          echo -e "\e[1;32m Daemon-reload completed \e[0m"

          #Try to start the kestral-eyeapi.service
          refreshPermissions "$$" & sudo service kestrel-eyeapi start
          refreshPermissions "$$" & sudo service kestrel-eye start
          refreshPermissions "$$" & sudo service kestrel-eyenotify start
          refreshPermissions "$$" & sudo service kestrel-eyescheduler start

          #systemctl is-active --quiet kestrel-eyeapi.service && echo "$(tput setaf 2) kestral-eyeapi.service is running" || echo "$(tput setaf 1) kestral-eyeapi.service is NOT running"
          eyeapistatus=$(sudo service kestrel-eyeapi status | grep Active:)
          #echo "$eyeapistatus"
          SAVEIFS=$IFS
          IFS=$' '
          eyeapistatus=($eyeapistatus)
          IFS=$SAVEIFS
          #echo "${eyeapistatus[1]}"
          if [[ "${eyeapistatus[1]}" == "active" ]];then
            echo -e "\e[1;32m Kestral.eyeapi service is running \e[0m"
          else
            echo -e "\e[1;31m Kestral.eyeapi service is not running \e[0m"
          fi

          eyenotifystatus=$(sudo service kestrel-eyenotify status | grep Active:)
          SAVEIFS=$IFS
          IFS=$' '
          eyenotifystatus=($eyenotifystatus)
          IFS=$SAVEIFS
         if [[ "${eyenotifystatus[1]}" == "active" ]];then
            echo -e "\e[1;32m Kestral.eyenotify service is running \e[0m"
          else
            echo -e "\e[1;31m Kestral.eyenotify service is not running \e[0m"
          fi

          eyeschedulerstatus=$(sudo service kestrel-eyescheduler status | grep Active:)
          SAVEIFS=$IFS
          IFS=$' '
          eyeschedulerstatus=($eyeschedulerstatus)
          IFS=$SAVEIFS
         if [[ "${eyeschedulerstatus[1]}" == "active" ]];then
            echo -e "\e[1;32m Kestral.eyescheduler service is running \e[0m"
          else
            echo -e "\e[1;31m Kestral.eyescheduler service is not running \e[0m"
          fi

          refreshPermissions "$$" & sudo chown root -R /srv/eye.communicator/
          #refreshPermissions "$$" & sudo cp -Rv eye.service /etc/systemd/system/

          #echo "Give me the user name"
          #read input

          #refreshPermissions "$$" & sudo usermod -a -G www-data $input
          #refreshPermissions "$$" & sudo chmod 644 /etc/systemd/system/kestrel-eye.service
          #refreshPermissions "$$" & sudo chmod 744 /srv/eye.service/eye.service


          #Try to start the kestral-eye.service
          refreshPermissions "$$" & sudo service kestrel-eye start
          #systemctl is-active --quiet kestrel-eye && echo "$(tput setaf 2) kestral-eye.service is running" || echo "$(tput setaf 1) kestral-eye.service is NOT running"
          eyestatus=$(sudo service kestrel-eye status | grep Active:)
          #echo "$eyestatus"
          SAVEIFS=$IFS
          IFS=$' '
          eyestatus=($eyestatus)
          IFS=$SAVEIFS
          #echo "${eyestatus[1]}"
          if [[ "${eyestatus[1]}" == "active" ]];then
            echo -e "\e[1;32m Kestral.eye service is running \e[0m"
          else
            echo -e "\e[1;31m Kestral.eye service is not running \e[0m"
          fi
        else
          echo -e "\e[1;31m Eye.scheduler files are not present \e[0m"
        fi
      else
        echo -e "\e[1;31m Eye.notifier files are not present \e[0m"
      fi
    else
      echo -e "\e[1;31m Eye-ui files are not present \e[0m"
    fi
  else
    echo -e "\e[1;31m Eye.api files are not present \e[0m"
  fi
else
  echo -e "\e[1;31m Eye.service files are not present \e[0m"
fi