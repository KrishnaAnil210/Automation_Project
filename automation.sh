#Updating the package details
sudo apt update -y

s3_bucket="upgrad-krishna"
myname="krishna"
timestamp=$(date '+%d%m%Y-%H%M%S')

#Installing apache2 if it is not already installed
REQUIRED_PKG="apache2"
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed")
echo "Checking for $REQUIRED_PKG"
if [ "" = "$PKG_OK" ]
then
  echo "No $REQUIRED_PKG. Setting up $REQUIRED_PKG."
  sudo apt-get --yes install $REQUIRED_PKG
else
  echo "Apache2 is already Installed"
fi


#Checking if the service is running or not
if pgrep -x "$REQUIRED_PKG" >/dev/null
then
    echo "$REQUIRED_PKG is running"
else
    echo "$REQUIRED_PKG stopped"
    systemctl start apache2
fi

#Checking if the service is enabled or not 
STATUS="$(systemctl is-active apache2)"
if [ "${STATUS}" = "active" ]; then
    echo "Apache2 Service is Enabled!"
else
    echo " Service not running.... so exiting "
    exit 1
fi



#Creating a tar archive of apache2 access logs and error logs that are present in the /var/log/apache2/ directory and place the tar into the /tmp/ directory
tar -czvf /tmp/${myname}-httpd-logs-${timestamp}.tar /var/log/apache2/*.log

#copying thr tar to the s3 bucket
aws s3 \
cp /tmp/${myname}-httpd-logs-${timestamp}.tar \
s3://${s3_bucket}/${myname}-httpd-logs-${timestamp}.tar

#checking if inventory file exists or not
FILE=/var/www/html/inventory.html
if test -f "${FILE}"; then
    echo "${FILE} exists."
else
    echo "Creating the file.."
    echo '<html><table><thead><tr><th>Log_Type</th><th>Date_Created</th><th>Type</th><th>Size</th></tr></thead></table></body></html>' > ${FILE}
fi

#appending data to the inventory file
size="$(du -h /tmp/${myname}-httpd-logs-${timestamp}.tar| awk '{print $1;}')"
echo "<table><tbody><tr><td>httpd-logs</td><td>${timestamp}</td><td>tar</td><td>${size}</td></tr></tbody></table>" >> $FILE



#Cron Job code
cron_job_status="$(crontab -l | grep Automation_Project/automation.sh)"
if [ "" = "${cron_job_status}" ]
then
  echo "No CronJob exists. Setting up a cron job."
  crontab -l | { cat; echo "0 3 * * * /root/Automation_Project/automation.sh"; } | crontab -
else
  echo "Cron Job already exists!!"
fi
