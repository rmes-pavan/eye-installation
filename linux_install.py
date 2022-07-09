import subprocess
import json
from getpass import getpass
import os
import datetime

DbName = 'rmdb1'
DbPassword = 'hotandcold'


yes_no = input("Do you want to use the same Db that your are using previously y/n : ")

if yes_no == 'y' or yes_no == 'Y' or yes_no == 'Yes' or yes_no == 'YES' or yes_no == 'yes':
    try:
        paths = [r'/var/www/eye.api/appsettings.Development.json', r'/var/www/eye.api/appsettings.json']
        for i in paths:
            file1 = open(i, 'r')
            app = file1.read()
            app = json.loads(app)
            line = (app['ConnectionStrings']['PostgreConnection'].split(";"))
            dbMachineIp = line[0].split("=")[1]
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
    dblocation = input("Is your db is in the same machine(y/n):-")

    if (dblocation == "y" or dblocation == "yes" or dblocation == "Y" or dblocation == "yes"):
        dbMachineIp = "localhost"
    else:
        dbMachineIp = input("give the Data - base machine IP:-")

    try:
        d1 = subprocess.check_output(
            f'psql postgresql://postgres:hotandcold@{dbMachineIp}:5432 -c "SELECT datname FROM pg_database  WHERE datistemplate = false;"'.format(
                'testsim@123'), shell=True)
        d1 = d1.decode('UTF-8')
        print(d1)
    except:
        print("not able to read the Db")

    DbName = input('Give me the name of data base you have:')
    DbPassword = getpass('Give the password of your data base: ')


print("...working")
# Stop kestral service

services = ["kestrel-eye","kestrel-eyeapi","kestrel-eyenotify","kestrel-eyescheduler","kestrel-eyeanalyticsBT",
            "kestrel-eyeanalyticsMIO","kestrel-eyeanalyticsMIP","kestrel-eyeanalyticsOLC","kestrel-eyeanalyticsRL","kestrel-eyeanalyticsWHS",
            'kestrel-eyedga','kestrel-eyereport','kestrel-eyeanalyticsHI','kestrel-eyeanalyticsHIDGA']
# stop kestral services

subprocess.call(f"sudo systemctl daemon-reload".format('testsim@123'), shell=True)

for service in services:
    subprocess.call(f'sudo service {service} stop'.format('testsim@123'), shell=True)
    subprocess.call(f'sudo rm -f /etc/systemd/system/{service}.service'.format('testsim@123'), shell=True)


#Taking maps backup if any
subprocess.call('sudo cp -rf /var/www/eye-ui/assets/maps .'.format('testsim@123'), shell=True)

#removing all the services and apis files
subprocess.call('sudo rm -rf /var/www/eye.api/'.format('testsim@123'), shell=True)
subprocess.call('sudo rm -rf /var/www/eye-ui/'.format('testsim@123'), shell=True)
subprocess.call('sudo rm -rf /srv/*'.format('testsim@123'), shell=True)

#installing the npm install
subprocess.call('npm i --prefix eye-reports-ui/'.format('testsim@123'), shell=True)


#putting all the files
subprocess.call('sudo cp -r eye.communicator /srv/'.format('testsim@123'), shell=True)
subprocess.call('sudo cp -r eye.api /var/www/'.format('testsim@123'), shell=True)
subprocess.call('sudo cp -r eye-ui /var/www/'.format('testsim@123'), shell=True)
subprocess.call('sudo cp -r eye.notifier /srv/'.format('testsim@123'), shell=True)
subprocess.call('sudo cp -r eye.scheduler /srv/'.format('testsim@123'), shell=True)
subprocess.call('sudo cp -r eye.analytics* /srv/'.format('testsim@123'), shell=True)
subprocess.call('sudo cp -r eye.dga /srv/'.format('testsim@123'), shell=True)
subprocess.call('sudo cp -r eye-reports-ui /srv/'.format('testsim@123'), shell=True)

#coping the nginx config file
subprocess.call('sudo cp services/nginx.conf /etc/nginx/'.format('testsim@123'), shell=True)


#coping the service files
for service in services:
    subprocess.call(f'sudo cp services/{service}.service /etc/systemd/system/'.format('testsim@123'), shell=True)


#Coping maps ip any
subprocess.call('sudo cp -rf maps /var/www/eye-ui/assets/'.format('testsim@123'), shell=True)


paths = [r'/var/www/eye.api/appsettings.Development.json',
         r'/var/www/eye.api/appsettings.json',
         r'/srv/eye.scheduler/appsettings.json',
         r'/srv/eye.scheduler/appsettings.Development.json',
        r'/srv/eye.analyticsBT/appsettings.json',
        r'/srv/eye.analyticsMIO/appsettings.json',
        r'/srv/eye.analyticsMIP/appsettings.json',
        r'/srv/eye.analyticsOLC/appsettings.json',
        r'/srv/eye.analyticsRL/appsettings.json',
        r'/srv/eye.analyticsWHS/appsettings.json',
        r'/srv/eye.dga/appsettings.json',
        r'/srv/eye.analyticsHI/appsettings.json',
        r'/srv/eye.analyticsHIDGA/appsettings.json',
         ]


for i in paths:
    file1 = open(i, 'r')
    app = file1.read()
    app = json.loads(app)
    line = (app['ConnectionStrings']['PostgreConnection'].split(";"))
    oldDbMachine = line[0].split("=")[1]
    OldDbName = line[2].split("=")[1]
    OldDbPassword = line[4].split("=")[1]
    subprocess.call(f'sudo sed -i "s/Database={OldDbName}/Database={DbName}/g" {i}'.format('testsim@123'), shell=True)
    subprocess.call(f'sudo sed -i "s/Password={OldDbPassword}/Password={DbPassword}/g" {i}'.format('testsim@123'), shell=True)
    subprocess.call(f'sudo sed -i "s/Host={oldDbMachine}/Host={dbMachineIp}/g" {i}'.format('testsim@123'),shell=True)



# writinh=g the quartz.config
subprocess.call('sudo rm /srv/eye.scheduler/quartz.config'.format('testsim@123'), shell=True)
directory = os.getcwd()
fileDirectory = directory+"/quartz.config"
file = open(fileDirectory,'w')
Lines = ['org.quartz.threadPool.threadCount = 30 \n',
         'org.quartz.jobStore.class = org.quartz.impl.jdbcjobstore.PostgreSQLDelegate \n',
         'quartz.jobStore.type = Quartz.Impl.AdoJobStore.JobStoreTX, Quartz \n',
         'quartz.jobStore.tablePrefix = job_ \n',
         'quartz.jobStore.dataSource = myDS \n',
         f'quartz.dataSource.myDS.connectionString = Host=127.0.0.1;Port=5432;Database={DbName};Username=rmtest;Password={DbPassword};Pooling=true;MinPoolSize=1;MaxPoolSize=95;ConnectionLifeTime=15; \n',
         'quartz.dataSource.myDS.provider = Npgsql \n',
         'quartz.serializer.type = json']
file.writelines(Lines)
file.close()

#coping the quartz config file.
subprocess.call(f"sudo cp {fileDirectory} /srv/eye.scheduler/".format('testsim@123'), shell=True)
#removing the file
subprocess.call(f"sudo rm {fileDirectory}".format('testsim@123'), shell=True)

# Getting the device ip;
c =subprocess.check_output('hostname -I'.format('testsim@123'), shell=True)
Ip = c.decode('UTF-8')
Ip = (Ip.split("\n")[0]).strip()
# hasDomain = input("Do you have any domain name(y/n):- ")

# if(hasDomain == 'n' or hasDomain == 'N' or hasDomain == 'NO' or hasDomain == "no"):
#     pass
# else:
#     Ip = input("Give me your domain name:-")



subprocess.call(f'sudo sed -i "2s/.*/      API_URL: \'http:\/\/{Ip}\/api\',/g" /var/www/eye-ui/assets/config.js'.format('testsim@123'), shell=True)
subprocess.call(f'sudo sed -i "3s/.*/      WS_URL: \'http:\/\/{Ip}\/notify\',/g\" /var/www/eye-ui/assets/config.js'.format('testsim@123'), shell=True)


subprocess.call(f"sudo systemctl daemon-reload".format('testsim@123'), shell=True)
for service in services:
    subprocess.call(f"sudo systemctl enable {service}".format('testsim@123'), shell=True)



subprocess.call(f"sudo service nginx start".format('testsim@123'), shell=True)
for service in services:
    subprocess.call(f"sudo service {service} start".format('testsim@123'), shell=True)




# removing th copied maps if they exist
subprocess.call('sudo rm -rf maps/'.format('testsim@123'), shell=True)
#
#
for service in services:
    subprocess.call(f'systemctl is-active --quiet {service}  && echo "$(tput setaf 2) {service} is running" || echo "$(tput setaf 1) {service} is NOT running"'.format('testsim@123'), shell=True)

subprocess.call("echo '\e[0;37m'", shell=True)

#Log the build upgrade

directory_path = os.getcwd()

folder_name = os.path.basename(directory_path)

with open("../build-log","a+") as f:
    f.write(f'{datetime.datetime.now()} : {folder_name} \n')


