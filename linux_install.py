import subprocess
import json
from getpass import getpass

DbName = 'rmdb1'
DbPassword = 'hotandcold'

yes_no = input("Do you want to use the same Db that your are using previously y/n : ")

if yes_no == 'y' or yes_no == 'Y' or yes_no == 'Yes' or yes_no == 'YES':
    try:
        paths = [r'/var/www/eye.api/appsettings.Development.json', r'/var/www/eye.api/appsettings.json']
        for i in paths:
            file1 = open(i, 'r')
            app = file1.read()
            app = json.loads(app)
            line = (app['ConnectionStrings']['PostgreConnection'].split(";"))
            DbName = line[2].split("=")[1]
            DbPassword = line[4].split("=")[1]
    except:
        d1 = subprocess.check_output(f' sudo -u postgres psql --command "SELECT datname FROM pg_database  WHERE datistemplate = false;"'.format('testsim@123'), shell=True)
        d1 = d1.decode('UTF-8')
        print(d1)
        print("Not able to read previous json files")
        DbName = input('Give me the data base you have:')
        print("password will not be shown")
        DbPassword = input('Give the password of your data base: ')
else:
    d1 = subprocess.check_output(f' sudo -u postgres psql --command "SELECT datname FROM pg_database  WHERE datistemplate = false;"'.format('testsim@123'), shell=True)
    d1 = d1.decode('UTF-8')
    print(d1)
    DbName = input('Give me the data base you have:')
    DbPassword = getpass('Give the password of your data base: ')



# Stop kestral service
subprocess.call('sudo service kestrel-eye stop'.format('testsim@123'), shell=True)
subprocess.call('sudo rm -f /etc/systemd/system/kestrel-eye.service'.format('testsim@123'), shell=True)

# stop kestral eyeapi
subprocess.call('sudo service kestrel-eyeapi stop'.format('testsim@123'), shell=True)
subprocess.call('sudo rm -f /etc/systemd/system/kestrel-eyeapi.service'.format('testsim@123'), shell=True)

# Stop Kestral eyenotify
subprocess.call('sudo service kestrel-eyenotify stop'.format('testsim@123'), shell=True)
subprocess.call('sudo rm -f /etc/systemd/system/kestrel-eyenotify.service'.format('testsim@123'), shell=True)


# Stop the eyescedular
subprocess.call('sudo service kestrel-eyescheduler stop'.format('testsim@123'), shell=True)
subprocess.call('sudo rm -f /etc/systemd/system/kestrel-eyescheduler.service'.format('testsim@123'), shell=True)



#Taking maps backup if any
subprocess.call('sudo cp -rf /var/www/eye-ui/assets/maps .'.format('testsim@123'), shell=True)

#removing all the services and apis files
subprocess.call('sudo rm -rf /srv/eye.service/'.format('testsim@123'), shell=True)
subprocess.call('sudo rm -rf /srv/eye.communicator/'.format('testsim@123'), shell=True)
subprocess.call('sudo rm -rf /var/www/eye.api/'.format('testsim@123'), shell=True)
subprocess.call('sudo rm -rf /var/www/eye-ui/'.format('testsim@123'), shell=True)
subprocess.call('sudo rm -rf /srv/eye.notifier/'.format('testsim@123'), shell=True)
subprocess.call('sudo rm -rf /srv/eye.scheduler/'.format('testsim@123'), shell=True)



#putting all the files
subprocess.call('sudo cp -r eye.communicator /srv/'.format('testsim@123'), shell=True)
subprocess.call('sudo cp -r eye.api /var/www/'.format('testsim@123'), shell=True)
subprocess.call('sudo cp -r eye-ui /var/www/'.format('testsim@123'), shell=True)
subprocess.call('sudo cp -r eye.notifier /srv/'.format('testsim@123'), shell=True)
subprocess.call('sudo cp -r eye.scheduler /srv/'.format('testsim@123'), shell=True)


#coping the service files
subprocess.call('sudo cp services/kestrel-eyeapi.service /etc/systemd/system/'.format('testsim@123'), shell=True)
subprocess.call('sudo cp services/kestrel-eye.service /etc/systemd/system/'.format('testsim@123'), shell=True)
subprocess.call('sudo cp services/kestrel-eyenotify.service /etc/systemd/system/'.format('testsim@123'), shell=True)
subprocess.call('sudo cp services/kestrel-eyescheduler.service /etc/systemd/system/'.format('testsim@123'), shell=True)


#Coping maps ip any
subprocess.call('sudo cp -rf maps /var/www/eye-ui/assets/'.format('testsim@123'), shell=True)


paths = [r'/var/www/eye.api/appsettings.Development.json',r'/var/www/eye.api/appsettings.json']
for i in paths:
    file1 = open(i, 'r')
    app = file1.read()
    app = json.loads(app)
    line = (app['ConnectionStrings']['PostgreConnection'].split(";"))
    OldDbName = line[2].split("=")[1]
    OldDbPassword = line[4].split("=")[1]
    subprocess.call(f'sudo sed -i "s/Database={OldDbName}/Database={DbName}/g" {i}'.format('testsim@123'), shell=True)
    subprocess.call(f'sudo sed -i "s/Password={OldDbPassword}/Password={DbPassword}/g" {i}'.format('testsim@123'), shell=True)

# Getting the device ip;
c =subprocess.check_output('hostname -I'.format('testsim@123'), shell=True)
Ip = c.decode('UTF-8')
Ip = (Ip.split("\n")[0]).strip()

subprocess.call(f'sudo sed -i "2s/.*/      API_URL: \'http:\/\/{Ip}\/api\',/g" /var/www/eye-ui/assets/config.js'.format('testsim@123'), shell=True)
subprocess.call(f'sudo sed -i "3s/.*/      WS_URL: \'http:\/\/{Ip}\/notify\',/g\" /var/www/eye-ui/assets/config.js'.format('testsim@123'), shell=True)

subprocess.call(f"sudo systemctl daemon-reload".format('testsim@123'), shell=True)
subprocess.call(f"sudo systemctl enable kestrel-eyeapi.service".format('testsim@123'), shell=True)
subprocess.call(f"sudo systemctl enable kestrel-eye.service".format('testsim@123'), shell=True)
subprocess.call(f"sudo systemctl enable kestrel-eyenotify.service".format('testsim@123'), shell=True)
subprocess.call(f"sudo systemctl enable kestrel-eyescheduler.service".format('testsim@123'), shell=True)


subprocess.call(f"sudo service kestrel-eyeapi start".format('testsim@123'), shell=True)
subprocess.call(f"sudo service kestrel-eye start".format('testsim@123'), shell=True)
subprocess.call(f"sudo service kestrel-eyenotify start".format('testsim@123'), shell=True)
subprocess.call(f"sudo service kestrel-eyescheduler start".format('testsim@123'), shell=True)

#
#
subprocess.call(f'systemctl is-active --quiet kestrel-eyeapi  && echo "$(tput setaf 2) kestral-api is running" || echo "$(tput setaf 1) kestral-api is NOT running"'.format('testsim@123'), shell=True)
subprocess.call(f'systemctl is-active --quiet kestrel-eye && echo "$(tput setaf 2) kestral-service is running" || echo "$(tput setaf 1) kestral-service is NOT running"'.format('testsim@123'), shell=True)
subprocess.call(f'systemctl is-active --quiet kestrel-eyenotify  && echo "$(tput setaf 2) kestrel-eyenotify is running" || echo "$(tput setaf 1) kestrel-eyenotify is NOT running"'.format('testsim@123'), shell=True)
subprocess.call(f'systemctl is-active --quiet kestrel-eyescheduler && echo "$(tput setaf 2) kestrel-eyescheduler is running" || echo "$(tput setaf 1) kestrel-eyescheduler is NOT running"'.format('testsim@123'), shell=True)

subprocess.call("echo '\e[0;37m'", shell=True)

