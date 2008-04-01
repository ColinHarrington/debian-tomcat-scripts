#!/bin/bash

sudo rm /usr/share/tomcat5.5/common/endorsed/*
cd /usr/share/tomcat5.5/common/lib
sudo apt-get install libmysql-java
sudo ln -s /usr/share/java/mysql-connector-java.jar
