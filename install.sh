#
# Install Mgx Core
#

# Install deps                                           
distrib="$(awk -F= '/^NAME/{print $2}' /etc/os-release)"                           
echo $distrib                                                                        
                                                                                
if [[ "$distrib" == *"Ubuntu"* ]]; then                                         
    apt-get -t drop install -y erlang
elif [[ "$distrib" == *"CentOS"* ]]; then                                          
    YUM_OPTS='--disablerepo="*" --enablerepo=drop'
    yum install $YUM_OPTS -y erlang
else                                                                            
    echo "undefine OS"                                                          
    exit 1                                                                      
fi                                                                              
                                                                                
# Build from source                                                             

export PATH=/opt/erlang/bin/:$PATH

cd /opt/drop-core
rm -rf deps
rm -rf .git

make clean && make deps && make
