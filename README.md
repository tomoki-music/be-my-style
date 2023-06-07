# README
* Ruby version 3.1.2

* How to run the test suite
bundle exec rspec spec

### Required
* ImageMagick(v7.1.1-5)
sudo yum -y install libpng-devel libjpeg-devel libtiff-devel gcc-c++ git
git clone -b 7.1.1-5 --depth 1 https://github.com/ImageMagick/ImageMagick.git ImageMagick-7.1.1-5
cd ImageMagick-7.1.1-5
./configure
make
sudo make install
* ChromeDriver
* MySQL
* Node.js
curl --silent --location https://rpm.nodesource.com/setup_16.x | sudo bash -
sudo yum install -y nodejs
