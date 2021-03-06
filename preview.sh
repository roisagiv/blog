#!/bin/bash

# Make sure this script is run alongside the hugo content
# even if run as an executable.
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR

echo -e "\033[0;32mSite running at http://localhost:1313/\033[0m"
open http://localhost:1313/
hugo server --watch --source=./
