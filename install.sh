#
# Install DROP Core
#

yum install -y https://localhost/RPMS/erlang-20.0.0-1.x86_64.rpm
export PATH=/opt/erlang/bin/:$PATH

cd /opt/drop-core
rm -rf deps
rm -rf .git

make clean && make deps && make
