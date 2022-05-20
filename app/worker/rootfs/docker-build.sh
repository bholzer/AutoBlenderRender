apt update
apt-get install -y ruby unzip git
gem install bundler

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf ./aws

# Install worker application
cd /worker 
gem build worker.gemspec
gem install worker