#!/bin/bash

# This is a script which uses BuildKit 0.2.0 to automatically package CKAN and
# its dependencies for use as Debian packages on Ubuntu 12.04 and 10.04.
#
# See the BuildKit documentation or look at the help to see what these commands
# do. eg:
#
#     buildkit --help
#
# The licenses and solrpy packages have to be built separately from the others
# because they are slighlty non-standard. All other CKAN dependencies are
# automatically handled by the --deps option to the CKAN build command.
# 
# Over time, as CKAN and its dependencies follow conventions more closely the
# edge cases handled by this script should go away and the build should become
# simpler.
#
# Install:
#
#     sudo apt-get update
#     sudo apt-get install -y wget
#     echo "deb http://apt.3aims.com/buildkit-0.2.2 lucid universe" | sudo tee /etc/apt/sources.list.d/3aims.list
#     wget -qO- "http://apt.3aims.com/packages_public.key" | sudo apt-key add -
#     sudo apt-get update
#     sudo apt-get install buildkit-deb buildkit-apt-repo


CKAN_PACKAGE_VERSION=$1
DEPS_PACKAGE_VERSION=$2
UBUNTU_RELEASE=$3
# If you don't run this command from the CKAN source directory, specify the 
# path to CKAN here
CKAN_PATH=$PWD
PIP_DOWNLOAD_CACHE=${CKAN_PATH}/build/env/cache
EMAIL=packaging@okfn.org
NAME="James Gardner"

# Clean the build environment
echo "Cleaning the environment ..."
rm -r ${CKAN_PATH}/dist/
rm -rf ${CKAN_PATH}/build/buildkit/env/src
mkdir -p ${CKAN_PATH}/dist/buildkit
echo "done."

echo "Building the packages ..."
# Create the python-ckan debian package
buildkit pkg python -p $CKAN_PACKAGE_VERSION \
                    --delete "solrpy" \
                    --distro-dep "python-solr" \
                    --rename "babel -> pybabel" \
                    --author-email="$EMAIL" \
                    --author-name="$NAME" \
                    --packager-email="$EMAIL" \
                    --packager-name="$NAME" \
                    --deps \
                    --exclude=test/generate_package \
                    --conflict-module "sqlalchemy-migrate -> migrate" \
                    --conflict-module "sqlalchemy -> lib/sqlalchemy" \
                    --conflict-module "pyutilib.component.core -> pyutilib" \
                    --conflict-module "solrpy -> solr" \
                    --conflict-module "zope.interface -> src/zope" \
                    --conflict-module "repoze.who -> repoze" \
                    --conflict-module "repoze.who-friendlyform -> repoze" \
                    --conflict-module "repoze.who.plugins.openid -> repoze" \
                    --conflict-module "psycopg2 -> psycopg" \
                    --conflict-module "pastescript -> paste" \
                    --debian-dir \
                    --url http://ckan.org \
                    --ubuntu-release "$UBUNTU_RELEASE" \
                    ${CKAN_PATH}

# Creates the ckan debian package (of which python-ckan is a dependency)
buildkit pkg nonpython -p $CKAN_PACKAGE_VERSION \
                       --deb \
                       --output-dir ${CKAN_PATH}/dist/buildkit \
                       --ubuntu-release "$UBUNTU_RELEASE" \
                       ${CKAN_PATH}/ckan_deb

# Build python-solr
SOLR_VERSION=`egrep '^solrpy' "${CKAN_PATH}/pip-requirements.txt"`
${CKAN_PATH}/build/buildkit/env/bin/pip install --download-cache ${CKAN_PATH}/build/buildkit/env/cache --no-install --upgrade $SOLR_VERSION
mv ${CKAN_PATH}/build/buildkit/env/build/solrpy ${CKAN_PATH}/build/buildkit/env/build/solr
# We need to rename the package here
sed -e "s,solrpy,solr," -i ${CKAN_PATH}/build/buildkit/env/build/solr/setup.py
# We need to specify an author explicitly since it is missing we'll use the CKAN one
buildkit pkg python -p $DEPS_PACKAGE_VERSION \
                    --author-email="$EMAIL" \
                    --author-name="$NAME" \
                    --packager-email="$EMAIL" \
                    --packager-name="$NAME" \
                    --debian-dir \
                    --ubuntu-release "$UBUNTU_RELEASE" \
                    ${CKAN_PATH}/build/buildkit/env/build/solr/

cp ${CKAN_PATH}/build/buildkit/env/build/solr/dist/buildkit/*.deb ${CKAN_PATH}/dist/buildkit/

echo "done."

# Add the .debs to the repository and the export the latest files for upload
# echo "Adding the packages to the $REPO_NAME repo using files in ${CKAN_PATH}/dist/buildkit/*.deb ..."
# sudo -u buildkit buildkit repo remove -a $REPO_NAME dummy_arg
# sudo -u buildkit buildkit repo add $REPO_NAME ${CKAN_PATH}/dist/buildkit/*.deb
# echo "done."
