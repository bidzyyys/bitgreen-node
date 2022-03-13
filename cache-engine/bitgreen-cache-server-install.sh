# welcome info 
echo
echo
echo "*** Welcome to the Bitgreen Cache Server Installer ***"
echo
echo "This will configure your server to cache the Bitgreen blockchain data in a local Postgresql database and serve the data via public API"
echo 

read -n 1 -s -r -p "Press any key to continue"
echo

# root privileges check
if [ "$EUID" -ne 0 ]
  then echo "Please run this script with root privileges"
  exit
fi

# hardware check !!
# ensure RAM is not less than 32 GB
if [ `free -m | head -2 | tail -1| awk '{print $2}'` -lt "32000" ]
    then echo "This computer has less than 32 GB of RAM"
    exit
fi

# disc space available 

# set hostname
echo
echo "Enter your desired hostname: "
read input_name
echo "You entered: ${input_name}!"
hostnamectl set-hostname $input_name 

# install Rust
echo "installing Rust..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
rustup install nightly
rustup default nightly
rustup target add wasm32-unknown-unknown
apt install clang
echo "Rust install and configuration successful"
echo

# install Bitgreen node
echo "cloning Bitgreen Github repository..."
git clone https://github.com/bitgreen/bitg-node.git
echo "Bitgreen Github repository successfully cloned"
echo
echo "building Bitgreen node..."
cd bitg-node
cargo build --release
echo "Bitgreen node build successful"
echo

# launch Bitgreen node
echo "launching Bitgreen node"
screen -d -m ./target/release/bitg-node
echo "Bitgreen node launched in detached screen environment"
echo

# install Postgresql
echo "installing Postgresql..."
apt install postgresql
echo "Postgresql install successful"
echo 

# generate random secure password (15 characters)
password=$(tr -dc 'A-Za-z0-9!"#$%&'\''()*+,-./:;<=>?@[\]^_`{|}~' </dev/urandom | head -c 15);
partA="ALTER USER postgres WITH PASSWORD '"
partB="';"
sqlString=$partA+=$password+=$partB
# echo $sqlString

# set postgres password
sudo -u postgres psql -c $sqlString

# PROMPT OR ALL RELEVANT INFO!!
echo "The Bitgreen installer will now open your environment file. Please input your relevant settings."
read -n 1 -s -r -p "Press any key to continue."
cd cache-engine
cp env.example .env
# nano .env

cat .env
>.env
echo '# this file was auto-generated by the Bitgreen installer'>.env
echo 'NODE_ENV=production'>>.env
echo '# postgresql config'>>.env
echo 'PGHOST=localhost'>>.env
echo 'PGUSER=postgresql'>>.env
echo 'PGDATABASE=cache-engine'>>.env
echo "PGPASSWORD="+=$password>>.env
echo 'PGPORT=5432'>>.env
echo '# rpc node provider'>>.env
echo 'RPC_PROVIDER=ws://127.0.0.1:9944'>>.env
echo '# api endpoint port'>>.env
echo 'API_PORT=3000'>>.env

# display password for admin purposes?

# clear password from environment variable after use
password="void"
sqlString="void"

:'
while true; do
    read -p "Is this server a master or a slave? (if unsure, select master)" ans
    case $ans in
        [Mm]* ) echo "master"; break;;
        [Ss]* ) echo "slave"; exit;;
        * ) echo "Please select 'm' for master or 's' for slave.";;
    esac
done

# POSTGRES TESTS
# Install initial PostgreSQL 10 cluster and verify it exists
sudo pg_lsclusters 

# create a second postgres cluster 
sudo pg_createcluster 10 replica1 
sudo pg_ctlcluster 10 replica1 status 
sudo systemctl status postgresql@10-main 

# create archive directories for both clusters 
sudo -H -u postgres mkdir /var/lib/postgresql/pg_log_archive/main 
sudo -H -u postgres mkdir /var/lib/postgresql/pg_log_archive/replica1 

# Configuration for master



# Configuration for slave

'

# configure Postgres with with tables describes in "migrations" folder
echo "configuring Postres"
cd cache-engine
npm install
npm run migrate up
echo "Postgres config complete"
echo 

# run crawler in detahced screen environment to download blocks and save to Postgres
screen -d -m npm run node
echo "Block crawler launched in detached screen environment"
echo

# run api server in detached screen environment to provide public endpoints
screen -d -m npm run api
echo "API service launched in detached screen environment"
echo
echo "Installation complete. Your Bitgreen node is up and running."
echo "Our bits are greener :)"
echo



