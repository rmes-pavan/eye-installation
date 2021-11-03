import subprocess
import json

d1 = subprocess.check_output(f' sudo -u postgres psql --command "SELECT datname FROM pg_database  WHERE datistemplate = false;"'.format('testsim@123'),shell=True)
d1 = d1.decode('UTF-8')
print(d1)
DbName = input('Give me the data base you have:')
DbPassword = input('Give the password of your data base: ')


# Stop kestral service
subprocess.call('sudo service kestrel-eye stop'.format('testsim@123'), shell=True)
subprocess.call('sudo rm -f /etc/systemd/system/kestrel-eye.service'.format('testsim@123'), shell=True)

# stop kestral eyeapi
subprocess.call('sudo service kestrel-eyeapi stop'.format('testsim@123'), shell=True)
subprocess.call('sudo rm -f /etc/systemd/system/kestrel-eyeapi.service'.format('testsim@123'), shell=True)

#removing all the services and apis files
subprocess.call('sudo rm -rf /srv/eye.service/'.format('testsim@123'), shell=True)
subprocess.call('sudo rm -rf /srv/eye.communicator/'.format('testsim@123'), shell=True)
subprocess.call('sudo rm -rf /var/www/eye.api/'.format('testsim@123'), shell=True)
subprocess.call('sudo rm -rf /var/www/eye-ui/'.format('testsim@123'), shell=True)



#putting all the files
subprocess.call('sudo cp -r eye.communicator /srv/'.format('testsim@123'), shell=True)
subprocess.call('sudo cp -r eye.api /var/www/'.format('testsim@123'), shell=True)
subprocess.call('sudo cp -r eye-ui /var/www/'.format('testsim@123'), shell=True)

#coping the service files
subprocess.call('sudo cp services/kestrel-eyeapi.service /etc/systemd/system/'.format('testsim@123'), shell=True)
subprocess.call('sudo cp services/kestrel-eye.service /etc/systemd/system/'.format('testsim@123'), shell=True)




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
subprocess.call(f'sudo sed -i "3s/.*/      WS_URL: \'http:\/\/{Ip}\/notify\'/g\" /var/www/eye-ui/assets/config.js'.format('testsim@123'), shell=True)

subprocess.call(f"sudo systemctl daemon-reload".format('testsim@123'), shell=True)
subprocess.call(f"sudo systemctl enable kestrel-eyeapi.service".format('testsim@123'), shell=True)
subprocess.call(f"sudo systemctl enable kestrel-eye.service".format('testsim@123'), shell=True)


subprocess.call(f"sudo service kestrel-eyeapi start".format('testsim@123'), shell=True)
subprocess.call(f"sudo service kestrel-eye start".format('testsim@123'), shell=True)


subprocess.call(f'systemctl is-active --quiet kestrel-eyeapi  && echo "$(tput setaf 2) kestral-api is running" || echo "$(tput setaf 1) kestral-api is NOT running"'.format('testsim@123'), shell=True)
subprocess.call(f'systemctl is-active --quiet kestrel-eye && echo "$(tput setaf 2) kestral-service is running" || echo "$(tput setaf 1) kestral-service is NOT running"'.format('testsim@123'), shell=True)
subprocess.call("echo '\e[0;37m'", shell=True)

