echo "Docker Installer"

function getOS() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            OS_TYPE="linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
          OS_TYPE="osx"
    fi

}

function getLocalIP() {
  getOS
  if [ "$OS_TYPE" == "linux" ]; then
    LOCAL_IP=$(ip route get 1 | awk '{print $NF;exit}')
  elif [ "$OS_TYPE" == "osx" ]; then
    LOCAL_IP=$(ipconfig getifaddr en0)
  fi
}

function escape_slashes {
    sed 's/\//\\\//g'
}

function change_line {
    local OLD_LINE_PATTERN=$1; shift
    local NEW_LINE=$1; shift
    local FILE=$1

    local NEW=$(echo "${NEW_LINE}" | escape_slashes)
    sed -i .bak '/'"${OLD_LINE_PATTERN}"'/s/.*/'"${NEW}"'/' "${FILE}"
    mv "${FILE}.bak" /tmp/
}

echo "127.0.0.1" > global/dockerip

#if command -v docker-machine &> /dev/null
#then
getLocalIP
    debug_ip=$LOCAL_IP
    cat_env=$(cat .env)
    cat_xdebug_host_env=$(cat .env | grep XDEBUG_HOST)

    echo "XDebug ip is $LOCAL_IP"
    change_line "$cat_xdebug_host_env" "XDEBUG_HOST=$LOCAL_IP" .env
    #echo "$LOCAL_IP" > global/dockerip
#fi

outside=$(cat .env | grep OUTSIDE)
outside="${outside//OUTSIDE_IP=/}"

hosts=$(cat /etc/hosts)
hosts_count=$(cat /etc/hosts | wc -l)
echo "" > global/hosts
for n in $( seq 1 $hosts_count)
do
    line=$(cat /etc/hosts | grep '' | sed -n "${n}p")
    line="${line:0:1}"
    if [ "$line" != "#" ]; then
      domain=$(cat /etc/hosts | grep '' | awk '{print $2}' | sed -n "${n}p")
      ip=$(cat /etc/hosts | grep '' | awk '{print $1}' | sed -n "${n}p")
      if [ "$domain" != "" ] && [ "$domain" != "localhost" ]; then
          line=$(cat /etc/hosts | grep '' | sed -n "${n}p")
          echo "$ip $domain" >> global/hosts
      fi
    fi
done

chmod +x global/setup.sh


if [ -f ".env" ]; then
  echo ".env already exists"
else
  echo "Creating .env"
  cp -n .env.example .env

  echo "Please enter projects path"
  echo "For example: /project/folder/path"

  read -p "Project Folder:" project_path
  if [ -z "$project_path" ]
  then
        echo "ERROR: Null"
        exit 1
  else
      sed -i "s#./sites_folder#$project_path#g" .env
      echo "writed..."
  fi

  echo ""
fi
echo ""

echo "Cleaning up... Configuration for elasticsearch"
sudo sysctl -w vm.max_map_count=262144
sudo sysctl -w fs.file-max=65536
docker-compose down
docker-compose up -d --build