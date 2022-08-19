#!/bin/bash

set -eo pipefail

OPTION=${1:-'all'}
KUBEAN_TAG=${KUBEAN_VERSION:-"v0.1.0"}

CURRENT_DIR=$(pwd)
OFFLINE_PACKAGE_DIR=${CURRENT_DIR}/${KUBEAN_TAG}

function generate_offline_dir() {
  mkdir -p $OFFLINE_PACKAGE_DIR
}

function generate_temp_list() {
  if [ ! -d "kubespray" ]; then
    echo "kubespray git repo should exist."
    exit 1
  fi
  echo "$CURRENT_DIR/kubespray"
  cd $CURRENT_DIR/kubespray
  bash contrib/offline/generate_list.sh
  cp contrib/offline/temp/*.list $OFFLINE_PACKAGE_DIR
}

function create_files() {
  cd $CURRENT_DIR/kubespray/contrib/offline/
  NO_HTTP_SERVER=true bash manage-offline-files.sh
  cp offline-files.tar.gz $OFFLINE_PACKAGE_DIR
}

function create_images() {
  cd $CURRENT_DIR/artifacts

  if which skopeo; then
    echo "skopeo check successfully"
  else
    echo "please install skopeo first"
    exit 1
  fi

  IMG_LIST=$CURRENT_DIR/kubespray/contrib/offline/temp/images.list

  echo "begin to download images"

  if [ ! -d "offline-images" ]; then
    echo "create dir offline-images"
    mkdir offline-images
  fi

  while read image_name; do
    ## quay.io/metallb/controller:v0.12.1 => dir:somedir/metallb%controller:v0.12.1
    new_dir_name=${image_name#*/}     ## remote host
    new_dir_name=${new_dir_name//\//%} ## replace all / with %
    echo "download image $image_name to local $new_dir_name"
    skopeo copy --retry-times=3 --override-os linux --override-arch amd64 docker://"$image_name" dir:offline-images/"$new_dir_name"
  done <"$IMG_LIST"

  tar -czvf $OFFLINE_PACKAGE_DIR/offline-images.tar.gz offline-images

  echo "zipping images completed!"
}

function copy_import_sh() {
    cp $CURRENT_DIR/artifacts/import_*.sh $OFFLINE_PACKAGE_DIR
}

case $OPTION in
all)
  generate_offline_dir
  generate_temp_list
  create_files
  create_images
  copy_import_sh
  ;;

list)
  generate_temp_list
  ;;

files)
  create_files
  ;;

images)
  create_images
  ;;

*)
  echo -n "unknown operator"
  ;;
esac
