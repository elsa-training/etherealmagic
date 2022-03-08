#!/usr/bash

if [ ! -d "$FE_REPO" ]; then
  git clone git@github.com:elsa-training/$FE_REPO.git
fi

cd $PWD/pixiemagic/
npm ci
npm run build
