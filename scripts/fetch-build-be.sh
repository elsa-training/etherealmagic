#!/usr/bash

if [ ! -d "$BE_REPO" ]; then
  git clone git@github.com:elsa-training/$BE_REPO.git
fi

sh $PWD/darkmagic/scripts/build-images.sh $PWD/darkmagic
