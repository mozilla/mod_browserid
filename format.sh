#!/bin/sh

if [ -z $1 ] ; then
  echo "Usage: $0 <file to style>"
  exit
fi

astyle --options=astyle.opt $1
