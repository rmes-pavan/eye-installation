import shutil
import os
import json
import subprocess
from getpass import getpass
import socket
import re

# checking whether dotnet is installed or not
# confirming that RMEYE is installed if dotnet was installed
dotnet_path = shutil.which("dotnet")
if dotnet_path is not None:
    print("Updating the version of RMEYE.")
    # Default file
    DbName = 'rmdb1'
    DbPassword = 'hotandcold'
    dbMachineIp = "localhost"

    yes_no = input("Do you want to use the same DB that your were using y/n : ")
    # get the DB credentials either from user or from json file
    if yes_no == 'y' or yes_no == 'Y' or yes_no == 'Yes' or yes_no == 'YES' or yes_no == 'yes':
        try:
            paths = [r'C:\RuggedMonitoring\eye.api\appsettings.Development.json']
            for i in paths:
                file1 = open(i, 'r')
                app = file1.read()
                app = json.loads(app)
                line = (app['ConnectionStrings']['PostgreConnection'].split(";"))
                dbMachineIp = line[0].split("=")[1]
                DbName = line[2].split("=")[1]
                DbPassword = line[4].split("=")[1]
                file1.close()
        except:
            d1= subprocess.check_output('psql -U postgres -c "SELECT datname FROM pg_database WHERE datistemplate = false;"', shell=True).decode('utf-8')
            d1 = d1.decode('UTF-8')
            print(d1)
            print("Not able to read previous json files")
            DbName = input('Give me the data base you have:')
            print("password will not be shown")
            DbPassword = input('Give the password of your data base: ')
    else:
        dblocation = input("Is your db is in the same machine(y/n):-")

        if (dblocation == "y" or dblocation == "yes" or dblocation == "Y" or dblocation == "yes"):
            dbMachineIp = "127.0.0.1"
        else:
            dbMachineIp = input("give the Data - base machine IP:-")

        try:
            d1 = subprocess.check_output(f'psql -h {dbMachineIp} -U postgres -d postgres -c "SELECT datname FROM pg_database WHERE datistemplate = false;"', shell=True)
            d1 = d1.decode('UTF-8')
            print(d1)
        except:
            print("not able to read the Db \n")
            print("Make Sure that postres binary path 'C:\\Program Files\\PostgreSQL\\<version>\\bin' to environment variables")

        DbName = input('Give me the name of data base you have:')
        DbPassword = getpass('Give the password of your data base: ')
    print("DB-IP:", {dbMachineIp})
    print("DB-Name:", {DbName})
    # stopping Apache and IIS
    os.system(r'C:\Apache24\bin\httpd -k stop')
    os.system('net stop w3svc')
    # Stopping node(reports)
    subprocess.run('pm2 kill', shell=True)
    # subprocess.run('pm2 stop C:\\RuggedMonitoring\\eye-reports-ui\\bin\\www', shell=True)
    # folder variables
    source_folder = os.getcwd()  # Get the current working directory
    destination_folder = r'C:\RuggedMonitoring'
    maps_folder = r'C:\RuggedMonitoring\eye-ui\assets\maps'
    backup_folder = r'C:\script_backups'
    backup_maps_folder = r'C:\script_backups\maps'

    # Delete the backup folder if it already exists
    if os.path.exists(backup_folder):
        shutil.rmtree(backup_folder)
        print('Removing if there is a backup folder')
    # checking if maps folder exists, if yes taking backup
    if os.path.exists(maps_folder):
        print('Taking Backup of Maps')
        # Copy the 'maps' folder to the backup folder
        try:
            shutil.copytree(maps_folder, backup_folder)
            print('Maps Backed up successfully')
        except shutil.Error as e:
            print(f'Backup error: {e}')
    else:
        print('No maps folder')
    # Delete the destination folder if it already exists
    print('Deleting Existing Source Folder')
    if os.path.exists(destination_folder):
        shutil.rmtree(destination_folder)

    # Copy all files and folders from the source to the destination
    print('Creating Source Folder and Copying New Build Folders')
    shutil.copytree(source_folder, destination_folder, dirs_exist_ok=True)

    # deleting backup folder which we have created above
    if os.path.exists(backup_folder):
        try:
            shutil.copytree(backup_folder, maps_folder)
            print('Restored Maps Folder')
        except shutil.Error as e:
            print(f'Delete backup error: {e}')
        shutil.rmtree(backup_folder)
        print('Backup folder deleted successfully')
    else:
        print('No Maps folder backup')

    print('Editing json files')
    paths = [r'C:\RuggedMonitoring\eye.api\appsettings.Development.json',
             r'C:\RuggedMonitoring\eye.api\appsettings.json',
             r'C:\RuggedMonitoring\eye.scheduler\appsettings.json',
             r'C:\RuggedMonitoring\eye.scheduler\appsettings.Development.json',
             r'C:\RuggedMonitoring\eye.analyticsBT\appsettings.json',
             r'C:\RuggedMonitoring\eye.analyticsMIO\appsettings.json',
             r'C:\RuggedMonitoring\eye.analyticsMIP\appsettings.json',
             r'C:\RuggedMonitoring\eye.analyticsOLC\appsettings.json',
             r'C:\RuggedMonitoring\eye.analyticsRL\appsettings.json',
             r'C:\RuggedMonitoring\eye.analyticsWHS\appsettings.json',
             r'C:\RuggedMonitoring\eye.dga\appsettings.json',
             r'C:\RuggedMonitoring\eye.analyticsHI\appsettings.json',
             r'C:\RuggedMonitoring\eye.analyticsHIDGA\appsettings.json',
             r'C:\RuggedMonitoring\eye.commoncal\appsettings.json',
             r'C:\RuggedMonitoring\eye.tpcalculator\appsettings.json',
             r'C:\RuggedMonitoring\eye.standardanalyticengine\appsettings.json',
             r'C:\RuggedMonitoring\eye.standardanalyticengine\appsettings.Development.json',
             r'C:\RuggedMonitoring\eye.timeranalyticengine\appsettings.json',
             r'C:\RuggedMonitoring\eye.dataimporter\appsettings.json'
            ]
    # reading previous database connection parameters
    for i in paths:
        file1 = open(i, 'r')
        app = file1.read()
        app = json.loads(app)
        line = (app['ConnectionStrings']['PostgreConnection'].split(";"))
        oldDbMachine = line[0].split("=")[1]
        OldDbName = line[2].split("=")[1]
        OldDbPassword = line[4].split("=")[1]
        file1.close()
    # Replacing strings in the above path files
        subprocess.run(
            f'powershell.exe -Command "(Get-Content {i}) -replace \'Database={OldDbName}\', \'Database={DbName}\' | Set-Content {i}"',
            shell=True)
        subprocess.call(
            f'powershell.exe -Command "(Get-Content {i}) -replace \'Password={OldDbPassword}\', \'Password={DbPassword}\' | Set-Content {i}"',
            shell=True)
        subprocess.call(
            f'powershell.exe -Command "(Get-Content {i}) -replace \'Host={oldDbMachine}\', \'Host={dbMachineIp}\' | Set-Content {i}"',
            shell=True)
    # Editing quartz.config file
    print('Editing quartz.config file')
    file = open(r'C:\RuggedMonitoring\eye.scheduler\quartz.config', 'w')
    Lines = ['org.quartz.threadPool.threadCount = 30 \n',
             'org.quartz.jobStore.class = org.quartz.impl.jdbcjobstore.PostgreSQLDelegate \n',
             'quartz.jobStore.type = Quartz.Impl.AdoJobStore.JobStoreTX, Quartz \n',
             'quartz.jobStore.tablePrefix = job_ \n',
             'quartz.jobStore.dataSource = myDS \n',
             f'quartz.dataSource.myDS.connectionString = Host={dbMachineIp};Port=5432;Database={DbName};Username=rmtest;Password={DbPassword};Pooling=true;MinPoolSize=1;MaxPoolSize=95;ConnectionLifeTime=15; \n',
             'quartz.dataSource.myDS.provider = Npgsql \n',
             'quartz.serializer.type = json']
    file.writelines(Lines)
    file.close()
    # starting npm
    subprocess.run('cd /d "C:\\RuggedMonitoring\\eye-reports-ui" && npm i --save', shell=True, check=True)
    # Fetching IP address of machine
    Domain=input('1. Give 1 if you have a domain \n'
                 '2. Give 2 to browse with IP. \n'
                 'Select the option: ')
    if int(Domain) == 1:
        IP = input('Please Give your Domain:')
    else:
        IP = socket.gethostbyname(socket.gethostname())
        print('Your machine IP and Browsing Address is', IP)
    # Asking input for environment for config.js file
    Env=input('What is environment you need to be set (RIL/RM)?')
    if Env == 'RIL' or Env == 'ril' or Env == 'Ril':
        Env='RIL'
    else:
        Env ='RM'
    print(Env)
    file_path = r"C:\RuggedMonitoring\eye-ui\assets\config.js"
    with open(file_path, 'r') as file:
        content = file.read()
    content = content.replace("localhost:5001", IP)
    content = content.replace("localhost:5050", IP)
    content = content.replace("https://", "http://")
    # content = re.sub(r"(API_URL:\s*')https?://[^/]+", fr"\1http://{IP}", content)
    content = re.sub(r"(COMPANY_NAME\s*:\s*)'.*?'", fr"\1'{Env}'", content)
    with open(file_path, 'w') as file:
        file.write(content)
        file.close()
    # Starting back Apache and services
    os.system('net start w3svc')
    os.system(r'C:\Apache24\bin\httpd -k start')
    subprocess.run('pm2 start C:\\RuggedMonitoring\\eye-reports-ui\\bin\\www', shell=True)
else:
    print("RMEYE is not installed, please install RMEYE to update the version.")